
use Test::Nginx::Socket::Lua::Stream;

repeat_each(2);
#repeat_each(1);

plan tests => repeat_each() * (blocks() * 3 + 1);

my $local_ip = `ifconfig | grep -oE '([0-9]{1,3}\\.?){4}' | grep '\\.' | grep -v '127.0.0.1' | head -n 1`;
chomp $local_ip;

$ENV{TEST_NGINX_SERVER_IP} ||= $local_ip;
$ENV{TEST_NGINX_NOT_EXIST_IP} ||= '8.8.8.8';
$ENV{TEST_NGINX_INVALID_IP} ||= '127.0.0.1:8899';

no_long_string();
#no_diff();
#log_level 'warn';
no_shuffle();

run_tests();

__DATA__

=== TEST 1: upstream sockets bind 127.0.0.1
--- stream_config
server {
   listen 2986;
   content_by_lua_block {
     ngx.say(ngx.var.remote_addr)
    }
}
--- stream_server_config
  content_by_lua_block {
      local ip = "127.0.0.1"
      local port = 2986
      local sock = ngx.socket.tcp()
      local ok, err = sock:bind(ip)
      if not ok then
          ngx.log(ngx.ERR, err)
          return
      end
      local ok, err = sock:connect("127.0.0.1", port)
      if not ok then
          ngx.log(ngx.ERR, err)
          return
      end


      local line, err, part = sock:receive()
      if line then
          ngx.say(line)
      else
          ngx.log(ngx.ERR, err)
      end
  }

--- stream_response
127.0.0.1
--- no_error_log
[error]


=== TEST 2: upstream sockets bind non loopback ip
--- stream_config
server {
   listen 2986;
   content_by_lua_block {
     ngx.say(ngx.var.remote_addr)
    }
}
--- stream_server_config
  content_by_lua_block {
      local ip = "$TEST_NGINX_SERVER_IP"
      local port = 2986
      local sock = ngx.socket.tcp()
      local ok, err = sock:bind(ip)
      if not ok then
          ngx.log(ngx.ERR, err)
          return
      end
      local ok, err = sock:connect("127.0.0.1", port)
      if not ok then
          ngx.log(ngx.ERR, err)
          return
      end

      local line, err, part = sock:receive()
      if line == ip then
        ngx.say("ip matched")
      else
        ngx.log(ngx.ERR, err)
      end
  }

--- stream_response
ip matched
--- no_error_log
[error]


=== TEST 3: upstream sockets bind not exist ip
--- stream_config
server {
   listen 2986;
   content_by_lua_block {
     ngx.say(ngx.var.remote_addr)
    }
}
--- stream_server_config
  content_by_lua_block {
      local ip = "$TEST_NGINX_NOT_EXIST_IP"
      local port = 2986
      local sock = ngx.socket.tcp()
      local ok, err = sock:bind(ip)
      if not ok then
          ngx.log(ngx.ERR, err)
      end

      local ok, err = sock:connect("127.0.0.1", port)
      if not ok then
        ngx.say(err)
      end
}

--- stream_response
cannot assign requested address
--- error_log eval
["bind(8.8.8.8) failed",
"lua tcp socket bind ip: 8.8.8.8"]


=== TEST 4: upstream sockets bind invalid ip
--- stream_config
server {
   listen 2986;
   content_by_lua_block {
     ngx.say(ngx.var.remote_addr)
    }
}
--- stream_server_config
  content_by_lua_block {
      local ip = "$TEST_NGINX_INVALID_IP"
      local port = 2986
      local sock = ngx.socket.tcp()
      local ok, err = sock:bind(ip)
      if not ok then
          ngx.say("failed to bind: ", err)
      end

      local ok, err = sock:connect("127.0.0.1", port)
      if not ok then
        ngx.log(ngx.ERR, err)
      end
}

--- stream_response
failed to bind: bad address
--- error_log eval
--- no_error_log
[error]
