# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.
#
# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# You can control the number of workers using ENV["WEB_CONCURRENCY"]. You
# should only set this value when you want to run 2 or more workers. The
# default is already 1. You can set it to `auto` to automatically start a worker
# for each available processor.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
#
# Cloud 66 (the Rails product) expects the application server to listen on a
# Unix socket instead. Set CUSTOM_WEB_SOCKET_FILE to switch to that mode; when
# the variable is absent the TCP port is used, as usual.
#
# Puma reads this file before Rails is loaded, so it only uses plain Ruby.
socket_file = ENV["CUSTOM_WEB_SOCKET_FILE"].to_s

if socket_file.empty?
  port ENV.fetch("PORT", 3000)
else
  bind "unix://#{File.expand_path(socket_file)}"
end

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run the Solid Queue supervisor inside of Puma for single-server deployments.
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the pid file if requested.
pid_file = ENV["CUSTOM_WEB_PID_FILE"].to_s
pid_file = ENV["PIDFILE"].to_s if pid_file.empty?
pidfile pid_file unless pid_file.empty?

# Cloud 66 runs the application from a release directory that changes on every
# deployment; pointing Puma at it makes the workers pick up the new code.
stack_path = ENV["STACK_PATH"].to_s
directory stack_path unless stack_path.empty?
