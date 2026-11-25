# The web server of Stockroom on Cloud 66 for Rails.
#
# Cloud 66 runs Passenger by default; the application is configured for Puma
# (see config/puma.rb), so Puma is started as the custom web process.
#
# Cloud 66 expects the web server to listen on a Unix socket and to write its
# pid file to a well known place. The socket and the pid file are also
# configurable through CUSTOM_WEB_SOCKET_FILE and CUSTOM_WEB_PID_FILE.
#
# The file is ignored by Cloud 66 Deploy, where the application runs in a
# container and the Dockerfile defines the start command.
custom_web: bundle exec puma -b unix:///tmp/web_server.sock --pidfile /tmp/web_server.pid
