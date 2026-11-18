import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

/// Production-ready structured logger with level filtering and formatted output.
class AppLogger {
  AppLogger._();

  static LogLevel minimumLevel = LogLevel.debug;

  static void debug(String message, {String tag = 'ShortsSplitter'}) {
    _log(LogLevel.debug, message, tag: tag);
  }

  static void info(String message, {String tag = 'ShortsSplitter'}) {
    _log(LogLevel.info, message, tag: tag);
  }

  static void warning(
    String message, {
    String tag = 'ShortsSplitter',
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.warning,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String message, {
    String tag = 'ShortsSplitter',
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _log(
    LogLevel level,
    String message, {
    required String tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minimumLevel.index) return;

    final prefix = switch (level) {
      LogLevel.debug => '🔍 [DEBUG]',
      LogLevel.info => 'ℹ️ [INFO]',
      LogLevel.warning => '⚠️ [WARN]',
      LogLevel.error => '❌ [ERROR]',
    };

    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final formattedMessage = '[$timestamp] $prefix [$tag] $message';

    developer.log(
      formattedMessage,
      name: tag,
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: stackTrace,
    );
  }
}
