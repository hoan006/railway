# Railway oriented programming

A functional approach to error handling. Inspired by Elixir `with` statement.

## Installation

### Plain Ruby

Run `gem install railway` in your terminal.

### Ruby on Rails

Add `gem 'railway', '~> 0.0.1'` to your Gemfile and run `bundle install`.

## Usage

1. Include the module

```ruby
  class LoginService
    include Railway

    def call(username, password)
      # More code to be added
    end
  end
```

2. Define your block to be executed and assign it to a variable

```ruby
  with { username.downcase }.as var(:cleaned_username)
```

3. Add a guard block if necessary

```ruby
    with { username.to_s.downcase }.as var(:cleaned_username)
      .when { cleaned_username.index( /[^[:alnum:]]/ ) == nil } # No special character
```

Note that `cleaned_username` is now available in the guard block

4. Repeat step 2, 3 with `then` function

```ruby
    with { username.downcase }.as var(:cleaned_username)
      .when { cleaned_username.index( /[^[:alnum:]]/ ) == nil } # No special character
      .then { password.to_s }.as var(:cleaned_password)
        .when { cleaned_password.length >= 6 } # Password minimum length required
        .then { authenticate(cleaned_username, cleaned_password) }.as var(:auth_result)
          .when { auth_result.present? }
```

5. Add an acceptance block when all guards are satsified

```ruby
    with # Redacted
          .when { auth_result.present? }
          .then do
      [:ok, auth_result.access_token]
    end
```

6. (Optional) Add a rejection block when any guard block interrupts the call chain
```ruby
    with # Redacted
          .when { auth_result.present? }
          .then do
      [:ok, auth_result.access_token]
    end.otherwise do |halted_by, halted_value|
      case halted_by
      when :cleaned_username
        [:error, "Invalid username: '#{halted_value}'"]
      when :cleaned_password
        [:error, "Password too short"]
      when :auth_result
        [:error, "Wrong username or password"]
      end
    end
```

## Caveats

## Note on Patches/Pull Requests

* Fork the project.
* Make your feature addition, maintenance or bug fix.
* Add tests for it. This is important so I don't break it in a future version unintentionally.
* Commit, but please do not mess with the gemspec, `VERSION`, `LICENSE`.
* Send me a pull request.
