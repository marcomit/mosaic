/* 
* BSD 3-Clause License
* 
* Copyright (c) 2025, Marco Menegazzi
* 
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
* 
* 1. Redistributions of source code must retain the above copyright notice, this
*   list of conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright notice,
*  this list of conditions and the following disclaimer in the documentation
*  and/or other materials provided with the distribution.
*
* 3. Neither the name of the copyright holder nor the names of its
*  contributors may be used to endorse or promote products derived from
*  this software without specific prior written permission.
* 
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
* AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
* CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
* OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
* OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mosaic/exceptions.dart';
import 'package:mosaic/src/mosaic.dart';
import 'package:mosaic/utils/rate_limiter.dart';

import 'logger_dispatcher.dart';
import 'logger_wrapper.dart';

/// The type of log message being recorded.
///
/// Used to categorize log messages by their severity and purpose.
/// This affects filtering, formatting, and routing to different outputs.
///
/// **Example:**
/// ```dart
/// logger.log('User logged in', type: LogType.info);
/// logger.log('Database connection failed', type: LogType.error);
/// ```
enum LogType {
  /// Detailed diagnostic information useful during development.
  ///
  /// Debug logs should contain technical details that help developers
  /// understand application flow and state. These are typically disabled
  /// in production for performance reasons.
  debug,

  /// General informational messages about application events.
  ///
  /// Info logs track normal application behavior and important milestones.
  /// These are useful for monitoring and auditing in production.
  info,

  /// Warning messages indicating potential issues or degraded performance.
  ///
  /// Warning logs highlight situations that aren't errors but may need
  /// attention or could lead to problems if not addressed.
  warning,

  /// Error conditions that indicate something has gone wrong.
  ///
  /// Error logs should be used for failures, exceptions, and other
  /// conditions that prevent normal operation.
  error,
}

/// Hierarchical log levels for filtering messages by importance.
///
/// Log levels provide a numeric hierarchy where higher-numbered levels
/// include all lower-numbered levels. This allows for granular control
/// over what gets logged in different environments.
///
/// **Example:**
/// ```dart
/// // Development: Show everything
/// logger.setLogLevel(LogLevel.debug);
///
/// // Production: Only warnings and errors
/// logger.setLogLevel(LogLevel.warning);
/// ```
enum LogLevel {
  /// Show all log messages (debug, info, warning, error).
  ///
  /// Typically used during development for maximum visibility into
  /// application behavior. Should be avoided in production due to
  /// performance impact.
  debug(0),

  /// Show informational messages and above (info, warning, error).
  ///
  /// Good default for staging environments where you want to track
  /// application flow without debug noise.
  info(1),

  /// Show warnings and errors only (warning, error).
  ///
  /// Recommended for production environments to focus on potential
  /// issues while maintaining performance.
  warning(2),

  /// Show only error messages (error).
  ///
  /// Use in high-performance production environments or when storage
  /// is limited. Only critical failures will be logged.
  error(3);

  /// Creates a log level with the specified numeric [value].
  ///
  /// The [value] determines the hierarchy - lower values are more verbose.
  const LogLevel(this.value);

  /// The numeric value representing this log level's position in the hierarchy.
  final int value;

  /// Determines whether this level should log messages of [other] level.
  ///
  /// Returns `true` if [other] should be logged based on this level's threshold.
  ///
  /// **Example:**
  /// ```dart
  /// LogLevel.warning.shouldLog(LogLevel.error); // true
  /// LogLevel.warning.shouldLog(LogLevel.debug); // false
  /// ```
  bool shouldLog(LogLevel other) => value <= other.value;
}

/// A production-ready logging system with advanced features.
///
/// The Logger class provides comprehensive logging capabilities including:
/// - **Multi-level filtering** with configurable thresholds
/// - **Tag-based organization** for targeted debugging
/// - **Multiple output destinations** via dispatchers
/// - **Rate limiting** to prevent log flooding
/// - **Asynchronous processing** for optimal performance
/// - **Automatic error recovery** with dispatcher failover
/// - **Memory-safe disposal** with proper resource cleanup
///
/// ## Quick Start
///
/// ```dart
/// void main() async {
///   await logger.init(
///     tags: ['app', 'network'],
///     dispatchers: [
///       ConsoleDispatcher(),
///       FileLoggerDispatcher(path: 'logs'),
///     ],
///   );
///
///   logger.setLogLevel(LogLevel.info);
///   logger.info('Application started', ['app']);
///
///   runApp(MyApp());
/// }
/// ```
///
/// ## Production Configuration
///
/// For production environments, consider:
/// - Setting level to [LogLevel.warning] or higher
/// - Using specific tags instead of logging everything
/// - Enabling file or remote dispatchers for persistence
/// - Configuring rate limiting for high-traffic scenarios
///
/// ```dart
/// // Production setup
/// await logger.init(
///   tags: ['error', 'critical'],
///   dispatchers: [FileLoggerDispatcher(), RemoteLogDispatcher()],
/// );
/// logger.setLogLevel(LogLevel.warning);
/// ```
///
/// ## Thread Safety
///
/// All Logger methods are thread-safe and can be called concurrently
/// from multiple isolates or async contexts without additional synchronization.
///
/// ## Memory Management
///
/// Always call [dispose] when the logger is no longer needed to prevent
/// memory leaks and ensure proper cleanup of resources.
///
/// See also:
/// * [Loggable] mixin for easy integration with classes
/// * [LoggerDispatcher] for custom output destinations
/// * [LoggerWrapper] for message formatting
class Logger {
  /// The minimum log level that will be processed.
  ///
  /// Messages below this level will be filtered out before dispatching.
  LogLevel _minLevel = LogLevel.info;

  /// Whether this logger instance has been disposed.
  ///
  /// Once disposed, the logger cannot be used and will throw exceptions
  /// if any logging methods are called.
  bool _disposed = false;

  /// Rate limiter to prevent log flooding and protect performance.
  ///
  /// Configured to allow 1000 messages per second by default.
  /// When exceeded, additional messages are dropped with a warning.
  final RateLimiter _rateLimiter = RateLimiter(
    window: const Duration(seconds: 1),
    maxRate: 1000,
  );

  /// Tags used to filter which log messages are processed.
  ///
  /// Only messages with at least one matching tag will be logged.
  /// If empty, all messages are processed regardless of tags.
  final Set<String> _tags = {};

  /// Map of active dispatchers that handle log output.
  ///
  /// Dispatchers are identified by name and can be enabled/disabled
  /// individually for flexible log routing.
  final Map<String, LoggerDispatcher> _dispatchers = {};

  /// Default tags automatically added to every log message.
  ///
  /// Useful for module-specific loggers or adding context like
  /// environment or application version to all logs.
  final Set<String> _defaultTags = {};

  /// Public getter of active dispatchers that handle log output.
  ///
  /// Dispatcher are identified by name and can be enabled/disabled
  /// individually for flexible log routing.
  /// Override the base class [LoggerDispatcher] to create custom dispatchers.
  /// Note:
  /// This is an unmodifiable version of private dispatchers so you cannot modify this object directly
  Map<String, LoggerDispatcher> get dispatchers =>
      Map.unmodifiable(_dispatchers);

  /// Message wrapper for applying formatting and transformations.
  ///
  /// Wrappers are applied in order before messages are sent to dispatchers.
  final _wrapper = LoggerWrapper();

  /// Adds log type prefix to messages.
  ///
  /// **Example output:** `"info: User logged in"`
  ///
  /// **Usage:**
  /// ```dart
  /// logger.addWrapper(Logger.addType);
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The original log message
  /// * [type] - The log type (debug, info, warning, error)
  /// * [tags] - List of tags associated with this log
  ///
  /// **Returns:** The message with type prefix added
  static String addType(String message, LogType type, List<String> tags) {
    return '${type.name}: $message';
  }

  /// Adds ISO 8601 timestamp prefix to messages.
  ///
  /// **Example output:** `'2025-01-15T10:30:45.123Z User logged in'`
  ///
  /// **Usage:**
  /// ```dart
  /// logger.addWrapper(Logger.addData);
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The original log message
  /// * [type] - The log type (debug, info, warning, error)
  /// * [tags] - List of tags associated with this log
  ///
  /// **Returns:** The message with timestamp prefix added
  static String addData(String message, LogType type, List<String> tags) {
    return '${DateTime.now().toIso8601String()} $message';
  }

  /// Adds tag list prefix to messages.
  ///
  /// **Example output:** `'[network,api] HTTP request completed'`
  ///
  /// **Usage:**
  /// ```dart
  /// logger.addWrapper(Logger.addTags);
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The original log message
  /// * [type] - The log type (debug, info, warning, error)
  /// * [tags] - List of tags associated with this log
  ///
  /// **Returns:** The message with tags prefix added
  static String addTags(String message, LogType type, List<String> tags) {
    return '[${tags.join(',')}] $message';
  }

  /// Adds current module name prefix to messages.
  ///
  /// Requires the module manager to be initialized with a current module.
  ///
  /// **Example output:** `'UserModule User logged in'`
  ///
  /// **Usage:**
  /// ```dart
  /// logger.addWrapper(Logger.addCurrentModule);
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The original log message
  /// * [type] - The log level (not used in this wrapper)
  ///
  /// **Returns:** The message with module name prefix added
  static String addCurrentModule(String message, LogLevel type) {
    return '${mosaic.registry.current.name} $message';
  }

  /// Creates a copy of this logger with additional default tags.
  ///
  /// The new logger inherits all configuration from the parent but adds
  /// the specified [defaultTags] to its default tag set. This is useful
  /// for creating module-specific loggers.
  ///
  /// **Example:**
  /// ```dart
  /// final userLogger = logger.copy(['user', 'authentication']);
  /// userLogger.info('Login attempt'); // Tagged with ['user', 'authentication']
  /// ```
  ///
  /// **Parameters:**
  /// * [defaultTags] - Additional tags to add to the default tag set
  ///
  /// **Returns:** A new Logger instance with the specified default tags
  ///
  /// **Note:** The returned logger must be manually initialized with [init].
  Logger copy([List<String> defaultTags = const []]) {
    final res = Logger();
    res._defaultTags.addAll(_defaultTags);
    res._defaultTags.addAll(defaultTags);
    res.init(tags: _tags.toList(), dispatchers: _dispatchers.values.toList());
    return res;
  }

  /// Sets the minimum log level for this logger.
  ///
  /// Messages below this level will be filtered out and not processed
  /// by any dispatchers. This is an efficient way to reduce logging
  /// overhead in production environments.
  ///
  /// **Example:**
  /// ```dart
  /// // Development: Show everything
  /// logger.setLogLevel(LogLevel.debug);
  ///
  /// // Production: Only warnings and errors
  /// logger.setLogLevel(LogLevel.warning);
  /// ```
  ///
  /// **Parameters:**
  /// * [level] - The minimum level to log
  ///
  /// **Performance Note:** Level filtering happens early in the logging
  /// pipeline, so setting a higher level in production significantly
  /// improves performance.
  void setLogLevel(LogLevel level) => _minLevel = level;

  /// Throws [LoggerException] if this logger has been disposed.
  ///
  /// This internal method is called by all public logging methods to
  /// ensure the logger is in a valid state before processing messages.
  ///
  /// **Throws:**
  /// * [LoggerException] if [dispose] has been called on this logger
  void _checkDisposed() {
    if (_disposed) {
      throw LoggerException(
        'You cannot log because the logger was already disposed',
      );
    }
  }

  /// Disposes of this logger and releases all resources.
  ///
  /// After disposal, this logger cannot be used for logging and will
  /// throw [LoggerException] if any logging methods are called.
  ///
  /// This method:
  /// - Disposes all registered dispatchers
  /// - Clears all internal collections
  /// - Marks the logger as disposed
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// void dispose() {
  ///   logger.dispose();
  ///   super.dispose();
  /// }
  /// ```
  ///
  /// **Important:** Always call this method when the logger is no longer
  /// needed to prevent memory leaks and ensure proper cleanup.
  ///
  /// **Note:** Dispatcher disposal errors are caught and ignored to ensure
  /// the logger disposal always completes successfully.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait(
      _dispatchers.values.map((d) => d.dispose().catchError((_) {})),
    );
    _dispatchers.clear();
    _defaultTags.clear();
    _tags.clear();
  }

  /// Initializes the logger with configuration options.
  ///
  /// This method must be called before any logging operations and should
  /// typically be called early in your application's startup sequence.
  ///
  /// **Configuration:**
  /// - **Tags:** Filter which messages get processed (empty = log everything)
  /// - **Dispatchers:** Where logs are sent (console, file, network, etc.)
  /// - **Default Tags:** Automatically added to every log message
  ///
  /// **Example:**
  /// ```dart
  /// await logger.init(
  ///   tags: ['network', 'auth', 'error'],
  ///   dispatchers: [
  ///     ConsoleDispatcher(),
  ///     FileLoggerDispatcher(path: 'logs'),
  ///     if (kDebugMode) DebugDispatcher(),
  ///   ],
  ///   defaultTags: ['myapp', 'v1.2.3'],
  /// );
  /// ```
  ///
  /// **Parameters:**
  /// * [tags] - List of tags to filter logs. Empty list means log everything
  /// * [dispatchers] - Output destinations for log messages
  /// * [defaultTags] - Tags automatically added to every log message
  ///
  /// **Performance Tips:**
  /// - Use specific tags in production to reduce processing overhead
  /// - Choose dispatchers based on your deployment environment
  /// - Keep default tags minimal to avoid unnecessary string operations
  ///
  /// **Throws:**
  /// * [LoggerException] if called on a disposed logger
  /// * Various exceptions if dispatcher initialization fails
  Future<void> init({
    required List<String> tags,
    required List<LoggerDispatcher> dispatchers,
    List<String>? defaultTags,
  }) async {
    _tags.clear();
    _tags.addAll(tags);

    _defaultTags.clear();
    if (defaultTags != null) _defaultTags.addAll(defaultTags);

    _dispatchers.clear();
    for (final dispatcher in dispatchers) {
      addDispatcher(dispatcher);
      await dispatcher.init();
    }
  }

  /// Adds a tag to the filter list.
  ///
  /// Messages with this tag will be processed by the logger.
  /// If the tag list is empty, all messages are processed.
  ///
  /// **Example:**
  /// ```dart
  /// logger.addTag('database');
  /// logger.addTag('performance');
  /// ```
  ///
  /// **Parameters:**
  /// * [tag] - The tag to add to the filter list
  ///
  /// **Performance Note:** Adding tags at runtime is thread-safe but
  /// may cause a brief pause in log processing.
  void addTag(String tag) => _tags.add(tag);

  /// Removes a tag from the filter list.
  ///
  /// Messages with only this tag will no longer be processed.
  /// If this was the last tag, all messages will be processed again.
  ///
  /// **Example:**
  /// ```dart
  /// logger.removeTag('debug');
  /// ```
  ///
  /// **Parameters:**
  /// * [tag] - The tag to remove from the filter list
  void removeTag(String tag) => _tags.remove(tag);

  /// Adds a dispatcher to handle log output.
  ///
  /// Dispatchers determine where log messages are sent (console, file,
  /// network, etc.). Multiple dispatchers can be active simultaneously.
  ///
  /// **Example:**
  /// ```dart
  /// logger.addDispatcher(ConsoleDispatcher());
  /// logger.addDispatcher(FileLoggerDispatcher(path: 'app.log'));
  /// logger.addDispatcher(SlackNotificationDispatcher());
  /// ```
  ///
  /// **Parameters:**
  /// * [dispatcher] - The dispatcher to add
  ///
  /// **Note:** If a dispatcher with the same name already exists,
  /// it will be replaced.
  void addDispatcher(LoggerDispatcher dispatcher) {
    _dispatchers[dispatcher.name] = dispatcher;
  }

  /// Enables or disables a specific dispatcher by name.
  ///
  /// This allows you to control log output destinations at runtime
  /// without removing dispatchers completely.
  ///
  /// **Example:**
  /// ```dart
  /// // Disable file logging temporarily
  /// logger.setDispatcher('file', false);
  ///
  /// // Re-enable it later
  /// logger.setDispatcher('file', true);
  /// ```
  ///
  /// **Parameters:**
  /// * [name] - The name of the dispatcher to enable/disable
  /// * [active] - Whether the dispatcher should be active
  ///
  /// **Use Cases:**
  /// - Temporarily disable expensive dispatchers during high load
  /// - Turn off debug output in production without removing dispatchers
  /// - Implement feature flags for different logging destinations
  void setDispatcher(String name, bool active) {
    if (!_dispatchers.containsKey(name)) return;
    _dispatchers[name]!.active = active;
  }

  /// Removes a dispatcher from the logger.
  ///
  /// The dispatcher will no longer receive log messages and should
  /// be disposed separately if needed.
  ///
  /// **Example:**
  /// ```dart
  /// final fileDispatcher = FileLoggerDispatcher();
  /// logger.addDispatcher(fileDispatcher);
  ///
  /// // Later...
  /// logger.removeDispatcher(fileDispatcher);
  /// await fileDispatcher.dispose();
  /// ```
  ///
  /// **Parameters:**
  /// * [dispatcher] - The dispatcher to remove
  ///
  /// **Note:** This method does not dispose the dispatcher automatically.
  void removeDispatcher(LoggerDispatcher dispatcher) {
    _dispatchers.remove(dispatcher.name);
  }

  /// Adds a message wrapper for formatting or transformation.
  ///
  /// Wrappers are applied in the order they were added and can modify
  /// log messages before they're sent to dispatchers.
  ///
  /// **Example:**
  /// ```dart
  /// // Add timestamp and log level
  /// logger.addWrapper(Logger.addData);
  /// logger.addWrapper(Logger.addType);
  ///
  /// // Custom wrapper
  /// logger.addWrapper((message, type, tags) {
  ///   return '[${DateTime.now().millisecondsSinceEpoch}] $message';
  /// });
  /// ```
  ///
  /// **Parameters:**
  /// * [c] - The wrapper callback function
  ///
  /// **Performance Note:** Each wrapper adds processing overhead,
  /// so use them judiciously in performance-critical applications.
  void addWrapper(LoggerWrapperCallback c) => _wrapper.add(c);

  /// Removes the most recently added wrapper.
  ///
  /// Wrappers are removed in LIFO (Last In, First Out) order.
  ///
  /// **Example:**
  /// ```dart
  /// logger.addWrapper(Logger.addType);
  /// logger.addWrapper(Logger.addData);
  /// logger.removeWrapper(); // Removes addData
  /// logger.removeWrapper(); // Removes addType
  /// ```
  ///
  /// **Note:** If no wrappers are present, this method does nothing.
  void removeWrapper() => _wrapper.remove();

  /// Converts a [LogType] to its corresponding [LogLevel].
  ///
  /// This mapping allows the level filtering system to work with
  /// the type-based logging methods.
  ///
  /// **Mapping:**
  /// - `LogType.debug` → `LogLevel.debug`
  /// - `LogType.info` → `LogLevel.info`
  /// - `LogType.warning` → `LogLevel.warning`
  /// - `LogType.error` → `LogLevel.error`
  LogLevel _typeToLevel(LogType type) {
    return switch (type) {
      LogType.info => LogLevel.info,
      LogType.debug => LogLevel.debug,
      LogType.error => LogLevel.error,
      LogType.warning => LogLevel.warning,
    };
  }

  /// Determines if a message of the given [type] should be logged.
  ///
  /// Returns `true` if the message's level meets or exceeds the
  /// configured minimum level.
  bool _shouldLog(LogType type) {
    final level = _typeToLevel(type);
    return _minLevel.shouldLog(level);
  }

  /// Determines if a message with the given [tags] should be processed.
  ///
  /// Returns `true` if:
  /// - The tag filter is empty (log everything), OR
  /// - At least one of the message tags matches a filter tag
  bool _canDispatch(List<String> tags) {
    if (_tags.isEmpty) return true;
    for (final tag in tags) {
      if (_tags.contains(tag)) return true;
    }
    return false;
  }

  /// Dispatches a log message to all active dispatchers.
  ///
  /// This internal method handles:
  /// - Tag-based filtering
  /// - Log level filtering
  /// - Rate limiting
  /// - Asynchronous dispatch to all active dispatchers
  ///
  /// Messages are processed asynchronously to avoid blocking the caller.
  Future<void> _dispatch(
    String message,
    LogType type,
    List<String> tags,
  ) async {
    final res = _canDispatch(tags);
    if (!res) return;

    if (!_shouldLog(type)) return;

    if (_rateLimiter.excedeed()) {
      debugPrint('Log rate limit exceeded, dropping message');
      return;
    }

    await Future.microtask(() async {
      await Future.wait(
        _dispatchers.values.map((d) => _safeDispatch(d, message, type, tags)),
      );
    });
  }

  /// Safely dispatches a message to a single dispatcher with error handling.
  ///
  /// This method provides:
  /// - Timeout protection (5 seconds)
  /// - Exception handling and logging
  /// - Automatic dispatcher disabling on repeated failures
  /// - Graceful degradation when dispatchers fail
  ///
  /// **Error Recovery:**
  /// - Network timeouts or IO errors automatically disable the dispatcher
  /// - Other errors are logged but don't affect the dispatcher's status
  /// - Failed dispatchers can be manually re-enabled later
  Future<void> _safeDispatch(
    LoggerDispatcher dispatcher,
    String message,
    LogType type,
    List<String> tags,
  ) async {
    if (!dispatcher.active) return;
    try {
      await dispatcher
          .log(message, type, tags)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[$dispatcher.name] Logger error: $e');
      debugPrint('Original message: $message');

      if (e is TimeoutException || e is IOException) {
        dispatcher.active = false;
        debugPrint(
          'Disabled dispatcher ${dispatcher.name} due to repeated failures',
        );
      }
    }
  }

  /// Logs a message with the specified type and tags.
  ///
  /// This is the primary logging method that all other convenience methods
  /// delegate to. It handles message wrapping, filtering, and dispatch.
  ///
  /// **Example:**
  /// ```dart
  /// await logger.log(
  ///   'User authentication failed',
  ///   type: LogType.error,
  ///   tags: ['auth', 'security'],
  /// );
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The message to log
  /// * [type] - The type/severity of the message (default: debug)
  /// * [tags] - Tags to associate with this message
  ///
  /// **Processing Pipeline:**
  /// 1. Check if logger is disposed
  /// 2. Apply message wrappers
  /// 3. Merge with default tags
  /// 4. Filter by tags and level
  /// 5. Apply rate limiting
  /// 6. Dispatch to all active dispatchers
  ///
  /// **Throws:**
  /// * [LoggerException] if the logger has been disposed
  ///
  /// **Performance:** This method returns immediately and processes
  /// the message asynchronously to avoid blocking the caller.
  Future<void> log(
    String message, {
    LogType type = LogType.debug,
    List<String> tags = const [],
  }) async {
    _checkDisposed();
    message = _wrapper.wrap(message, type, tags);

    await _dispatch(message, type, [..._defaultTags, ...tags]);
  }

  /// Logs a debug message.
  ///
  /// Debug messages contain detailed diagnostic information useful during
  /// development but typically disabled in production for performance.
  ///
  /// **Example:**
  /// ```dart
  /// await logger.debug('Processing user request ${request.id}', ['api']);
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The debug message to log
  /// * [tags] - Optional tags to associate with this message
  ///
  /// **Best Practices:**
  /// - Include relevant context (IDs, states, parameters)
  /// - Use specific tags for easy filtering
  /// - Avoid logging sensitive information
  /// - Consider performance impact in tight loops
  Future<void> debug(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.debug, tags: tags);
  }

  /// Logs an informational message.
  ///
  /// Info messages track normal application behavior and important
  /// milestones. These are useful for monitoring and auditing.
  ///
  /// **Example:**
  /// ```dart
  /// await logger.info('User ${userId} logged in successfully', ['auth']);
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The informational message to log
  /// * [tags] - Optional tags to associate with this message
  ///
  /// **Best Practices:**
  /// - Log significant business events
  /// - Include user/session context when relevant
  /// - Keep messages concise but informative
  /// - Use consistent formatting for similar events
  Future<void> info(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.info, tags: tags);
  }

  /// Logs a warning message.
  ///
  /// Warning messages indicate potential issues or degraded performance
  /// that don't prevent operation but may need attention.
  ///
  /// **Example:**
  /// ```dart
  /// await logger.warning('API response time exceeded 2s', ['performance']);
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The warning message to log
  /// * [tags] - Optional tags to associate with this message
  ///
  /// **Best Practices:**
  /// - Highlight performance degradation
  /// - Note recoverable errors or fallback usage
  /// - Include metrics or thresholds when relevant
  /// - Tag with components that might need attention
  Future<void> warning(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.warning, tags: tags);
  }

  /// Logs an error message.
  ///
  /// Error messages indicate failures, exceptions, or other conditions
  /// that prevent normal operation and require attention.
  ///
  /// **Example:**
  /// ```dart
  /// await logger.error('Database connection failed: ${e.toString()}', ['db']);
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The error message to log
  /// * [tags] - Optional tags to associate with this message
  ///
  /// **Best Practices:**
  /// - Include error details and context
  /// - Add stack traces for debugging (in debug mode)
  /// - Tag with affected components
  /// - Consider alerting mechanisms for critical errors
  Future<void> error(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.error, tags: tags);
  }
}

/// A mixin that provides convenient logging methods for classes.
///
/// This mixin adds logging capabilities to any class without requiring
/// direct logger dependencies. It automatically includes the class's
/// [loggerTags] in all log messages.
///
/// **Example:**
/// ```dart
/// class UserService with Loggable {
///   @override
///   List<String> get loggerTags => ['user', 'service'];
///
///   Future<User> login(String email, String password) async {
///     info('Login attempt for $email'); // Tagged with ['user', 'service']
///
///     try {
///       final user = await authenticateUser(email, password);
///       info('Login successful for $email');
///       return user;
///     } catch (e) {
///       error('Login failed for $email: $e');
///       rethrow;
///     }
///   }
/// }
/// ```
///
/// ## Module Integration
///
/// The mixin is particularly useful for module classes where you want
/// consistent tagging across all operations:
///
/// ```dart
/// class PaymentModule extends Module with Loggable {
///   @override
///   List<String> get loggerTags => ['payment', name];
///
///   @override
///   Future<void> onInit() async {
///     info('Payment module initializing');
///     await setupStripeConfig();
///     info('Payment module ready');
///   }
/// }
/// ```
///
/// ## Performance Considerations
///
/// The mixin methods delegate to the global [logger] instance, so all
/// performance characteristics (filtering, rate limiting, etc.) apply.
/// Tag merging happens on each call, so avoid excessive logging in
/// performance-critical paths.
///
/// ## Error Handling
///
/// All methods in this mixin can throw [LoggerException] if the global
/// logger has been disposed. This typically happens during application
/// shutdown and should be handled gracefully.
mixin Loggable {
  /// Default tags automatically added to all log messages from this class.
  ///
  /// Override this getter to provide context-specific tags that identify
  /// the source of log messages. Common patterns include:
  ///
  /// **Component-based tagging:**
  /// ```dart
  /// @override
  /// List<String> get loggerTags => ['database', 'user_repository'];
  /// ```
  ///
  /// **Hierarchical tagging:**
  /// ```dart
  /// @override
  /// List<String> get loggerTags => ['api', 'v2', 'users'];
  /// ```
  ///
  /// **Instance-based tagging:**
  /// ```dart
  /// @override
  /// List<String> get loggerTags => ['worker', 'instance_$id'];
  /// ```
  ///
  /// **Default:** Returns an empty list (no automatic tags)
  ///
  /// **Performance Note:** This getter is called for every log message,
  /// so avoid expensive computations. Consider caching dynamic tags.
  List<String> get loggerTags => [];

  /// Logs a message with the specified type and additional tags.
  ///
  /// This is the primary logging method that merges the class's [loggerTags]
  /// with any additional tags provided in the call.
  ///
  /// **Example:**
  /// ```dart
  /// await log(
  ///   'Processing payment for order ${orderId}',
  ///   type: LogType.info,
  ///   tags: ['processing', 'order_$orderId'],
  /// );
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The message to log
  /// * [type] - The type/severity of the message (default: info)
  /// * [tags] - Additional tags to merge with [loggerTags]
  ///
  /// **Tag Merging:** The final tag list will be `[...loggerTags, ...tags]`,
  /// so class tags appear first, followed by method-specific tags.
  ///
  /// **Throws:**
  /// * [LoggerException] if the global logger has been disposed
  Future<void> log(
    String message, {
    LogType type = LogType.info,
    List<String> tags = const [],
  }) async {
    await mosaic.logger.log(
      message,
      type: type,
      tags: [...loggerTags, ...tags],
    );
  }

  /// Logs a debug message with automatic tag merging.
  ///
  /// Debug messages contain detailed diagnostic information useful during
  /// development. The class's [loggerTags] are automatically included.
  ///
  /// **Example:**
  /// ```dart
  /// await debug('Cache hit for key: $cacheKey', ['cache', 'performance']);
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The debug message to log
  /// * [tags] - Additional tags to merge with [loggerTags]
  ///
  /// **Best Practices:**
  /// - Include relevant state information
  /// - Use specific tags for easy filtering during debugging
  /// - Avoid logging sensitive data (passwords, tokens, etc.)
  /// - Consider the performance impact in tight loops
  ///
  /// **Throws:**
  /// * [LoggerException] if the global logger has been disposed
  Future<void> debug(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.debug, tags: tags);
  }

  /// Logs an informational message with automatic tag merging.
  ///
  /// Info messages track normal application behavior and important
  /// milestones. The class's [loggerTags] are automatically included.
  ///
  /// **Example:**
  /// ```dart
  /// await info('User ${user.id} profile updated successfully');
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The informational message to log
  /// * [tags] - Additional tags to merge with [loggerTags]
  ///
  /// **Best Practices:**
  /// - Log significant business events and state changes
  /// - Include relevant identifiers (user IDs, transaction IDs, etc.)
  /// - Keep messages concise but informative
  /// - Use consistent formatting for similar operations
  ///
  /// **Throws:**
  /// * [LoggerException] if the global logger has been disposed
  Future<void> info(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.info, tags: tags);
  }

  /// Logs a warning message with automatic tag merging.
  ///
  /// Warning messages indicate potential issues or degraded performance
  /// that don't prevent operation but may need attention. The class's
  /// [loggerTags] are automatically included.
  ///
  /// **Example:**
  /// ```dart
  /// await warning('API rate limit approaching: ${requests}/${limit}');
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The warning message to log
  /// * [tags] - Additional tags to merge with [loggerTags]
  ///
  /// **Best Practices:**
  /// - Highlight performance degradation or resource constraints
  /// - Note when fallback mechanisms are used
  /// - Include relevant metrics or thresholds
  /// - Tag with components that might need attention
  ///
  /// **Throws:**
  /// * [LoggerException] if the global logger has been disposed
  Future<void> warning(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.warning, tags: tags);
  }

  /// Logs an error message with automatic tag merging.
  ///
  /// Error messages indicate failures, exceptions, or other conditions
  /// that prevent normal operation and require immediate attention.
  /// The class's [loggerTags] are automatically included.
  ///
  /// **Example:**
  /// ```dart
  /// await error('Failed to process payment: ${exception.message}', ['critical']);
  /// ```
  ///
  /// **Parameters:**
  /// * [message] - The error message to log
  /// * [tags] - Additional tags to merge with [loggerTags]
  ///
  /// **Best Practices:**
  /// - Include exception details and relevant context
  /// - Add stack traces in development environments
  /// - Tag with severity indicators ('critical', 'recoverable')
  /// - Consider triggering alerts for critical errors
  /// - Include correlation IDs for distributed systems
  ///
  /// **Throws:**
  /// * [LoggerException] if the global logger has been disposed
  Future<void> error(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.error, tags: tags);
  }
}
