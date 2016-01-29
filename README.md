# pinocchio

## Description:
`pinocchio` is a primative configuration management tool in Perl. It currently does the following:

* install various packagaes
* copy `nginx` configuration files
* stop/start services
* update `nginx` DocumentRoot (via a public `git` repo)

It's influenced by Ansible and tries to mimic it's execution method.

* Uses a YAML file for configuration *directives*, though not as flexible as Ansible.
* Generates a `bash` script and copies that to the remote host for execution.

## Command Syntax
This only one required command line parameter.

*  -p `<ssh password>`

To execute `pinocchio.pl` with debugging messages:

`./pinoccio.pl -v -p blahblah`

## Samples
### Same Verbose Output
	mrz@nimba [~/pinocchio/] 124> ./pinocchio.pl -p mypassword -v
	 [VERBOSE] Writing output script => /tmp/pinocchio-ytRPY.tmp
	  [] [PACKAGES] apt-get -y install nginx
	  [] [PACKAGES] apt-get -y install php5-fpm
	  [] [PACKAGES] apt-get -y install git
	 [VERBOSE] Calling: clonewebroot with: /usr/share/nginx/html, https://github.com/mzeier/pinocchio-web.git
	  [] [CLONE WEBROOT] git clone/pull https://github.com/mzeier/pinocchio-web.git
	 [VERBOSE] Calling: stop/start services
	  [] [START] service nginx stop/start
	  [] [ssh] Connecting: root@127.0.0.1
	  [] [ssh] Copying: scp /tmp/pinocchio-ytRPY.tmp root@127.0.0.1:/tmp/
	  [] [ssh] Copying: scp nginx.conf.template -> /etc/nginx/sites-enabled/default
	  [] [ssh] Exec'ing /tmp/pinocchio-ytRPY.tmp
	
	(apt-get output skipped)
	
	Cloning into 'pinocchio-web'...

### Sample `bash` script
This is an example of the script output that is generated and copied to remove hosts.

~~~bash
#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
apt-get -y install nginx
apt-get -y install php5-fpm
apt-get -y install git

if [ ! -d "/usr/share/nginx/html/pinocchio-web" ]; then
 cd /usr/share/nginx/html
 git clone https://github.com/mzeier/pinocchio-web.git
fi
cd /usr/share/nginx/html/pinocchio-web
git pull

service nginx stop
service nginx start
~~~

## Validation Output

Testing output:

	mrz@nimba [~/pinocchio/] 75> curl -s http://50.16.88.200/
	Hello, world!
	
	mrz@nimba [~/pinocchio/] 76> curl -s http://54.147.243.124/
	Hello, world!
	
Verbose output:

	mrz@nimba [~/pinocchio/] 77> curl -sv http://54.147.243.124/
	* About to connect() to 54.147.243.124 port 80 (#0)
	*   Trying 54.147.243.124...
	* Connected to 54.147.243.124 (54.147.243.124) port 80 (#0)
	> GET / HTTP/1.1
	> User-Agent: curl/7.29.0
	> Host: 54.147.243.124
	> Accept: */*
	>
	< HTTP/1.1 200 OK
	< Server: nginx/1.4.6 (Ubuntu)
	< Date: Fri, 29 Jan 2016 17:59:28 GMT
	< Content-Type: text/plain
	< Transfer-Encoding: chunked
	< Connection: keep-alive
	< X-Powered-By: PHP/5.5.9-1ubuntu4.14
	<
	Hello, world!
	* Connection #0 to host 54.147.243.124 left intact
	
	mrz@nimba [~/pinocchio/] 78> curl -sv http://50.16.88.200/
	* About to connect() to 50.16.88.200 port 80 (#0)
	*   Trying 50.16.88.200...
	* Connected to 50.16.88.200 (50.16.88.200) port 80 (#0)
	> GET / HTTP/1.1
	> User-Agent: curl/7.29.0
	> Host: 50.16.88.200
	> Accept: */*
	>
	< HTTP/1.1 200 OK
	< Server: nginx/1.4.6 (Ubuntu)
	< Date: Fri, 29 Jan 2016 17:59:35 GMT
	< Content-Type: text/plain
	< Transfer-Encoding: chunked
	< Connection: keep-alive
	< X-Powered-By: PHP/5.5.9-1ubuntu4.14
	<
	Hello, world!
	* Connection #0 to host 50.16.88.200 left intact
