# RESTful memcached

RESTful memcached (RESTmc) is a simple Sinatra app that provides a REST interface to an Infinispan cache running in a Torquebox container.

## Usage

Load this in Torquebox through your usual means.

The access pattern is:

	:base_url/:cache_name/:key

Or something like:

	http://localhost/cache-home/cache_1/key_1

Cache opterations look like:

	GET    -> get
	POST   -> add
	PUT    -> set (also incr/decr)
	DELETE -> delete

Both `POST` and `PUT` use the request body as the value to store.

### Example curl Commands

```
	# List the caches for this app.
	% curl -X GET http://localhost/cache-home/
	cache_1
	cache_2
	cache_3
```
```
	# List the keys for a cache.
	% curl -X GET http://localhost/cache-home/cache_1/
	key_1
	key_2
	key_3
```
```
	# Get a key
	% curl -X GET http://localhost/cache-home/cache_1/key_1
	value_1
```
```
	# Add a value for a key (if it doesn't already exist)
	% curl -X POST -d "value" http://localhost/cache-home/cache_1/key_1
```
```
	# Set a value for a key (whether it exists or not)
	% curl -X PUT -d "value" http://localhost/cache-home/cache_1/key_1
```
```
	# Delete a key/value pair from the cache
	curl -X DELETE http://localhost/cache-home/cache_1/key_1
```
```
	# Delete an entire cache
	curl -X DELETE http://localhost/cache-home/cache_1/
```



### `incr` and `decr` Commands

The `PUT` verb can also be used to increment and decrement counters (i.e. the `incr` and `decr` memcached commands).  Use of these is as simple as augmenting the key (URL) with a `+` or `-` appropriately.  The amount to increase/decrease the key by is given in the request body; the default is 1 (one) if not provided.  For example:

	curl -X PUT -d "1" http://localhost/cache-home/:cache_name/%2B/:key
	curl -X PUT -d "1" http://localhost/cache-home/:cache_name/-/:key

Please note the use of the URL-encoded form of the `+` symbol: `%2B`.  Using a raw `+` will be treated as a space character and will return an invalid key exception.

#### Non-Existent Keys

Increasing an unset key will result in that key being created with an initial value of the amount to increase by (defaulting to 1); decreasing an unset key will cause that key to be created with an initial value of 0 (zero).

### Return Values

All successful `GET` requests are returned as `text/plain` with an HTTP status code of `200 OK`.  A `GET` or `DELETE` request for a non-existent key will return a `404 Not Found` status; a `POST` requested for a key which already exists will return `409 Conflict`.

### Key Namespacing

You can specify keys either by exact name, or can make use of the auto-namespacing by providing a full path, the parts of which are concatenated together with a colon (`:`) as a separator to form the key:

	GET /path_to_key -> path_to_key
	GET /path/to/key -> path:to:key

### Key Expiry

You can set an expiry time for a key when using a `POST` or `PUT` command by using the `Cache-Control` HTTP header to specify a timeout in seconds.  The default is `0` (i.e. never expire).

	curl -X PUT -d "value" -H "Cache-Control: max-age=5" \
		http://localhost:9393/path_to_key

## Requirements

RESTmc requires the [Sinatra](http://www.sinatrarb.com/) and [memcached](http://github.com/fauna/memcached) gems to be installed, and a [memcached](http://memcached.org/) instance to be running on `localhost:11211`.

## Licensing and Attribution

RESTmc was developed by [Tim Blair](http://tim.bla.ir/) and has been released under the MIT license as detailed in the LICENSE file that should be distributed with this library; the source code is [freely available](http://github.com/timblair/restful-memcached).
