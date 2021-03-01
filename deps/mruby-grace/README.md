# mruby-grace

mruby-grace is a sinatra like dsl for mruby which is based on [katzer/mruby-r3](https://github.com/katzer/mruby-r3)

## Install by mrbgems

- add conf.gem line to `build_config.rb`

```ruby
MRuby::Build.new do |conf|

    # ... (snip) ...

    conf.gem :git => 'https://github.com/accaman/mruby-grace.git'
end
```

## Usages

You can define routes simply.

```yaml
mruby.handler: |
  klass = Class.new(Grace) do
    get "/users/{name}" do |name|
      [200, { "content-type" => "text/plain" }, ["Hello #{ name }\n"]]
    end
  end
  klass.new
```

You can of course use `env` in callback.

```yaml
mruby.handler: |
  klass = Class.new(Grace) do
    get "/request" do
      [200, { "content-type" => "text/plain" }, ["#{ env["REQUEST_METHOD"] } #{ env["SCRIPT_NAME"] }#{ env["PATH_INFO"] }\n"]]
    end
  end
  klass.new
```

## License

under the MIT License:

- see LICENSE file
