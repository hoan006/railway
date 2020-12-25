# Railway oriented programming

A functional approach to error handling. Inspired by Elixir `with` statement.

## Installation

### Plain Ruby

Run `gem install railway` in your terminal.

### Ruby on Rails

Add `gem 'railway', '~> 0.0.1'` to your Gemfile and run `bundle install`.

## Background

Here's a typical login service

```ruby
class LoginService
  include Railway

  def call(username, password)
    @username = username
    @password = password

    unless cleaned_username.index( /[^[:alnum:]]/ ) == nil
      return [:error, "Invalid username: '#{cleaned_username}'"]
    end

    unless cleaned_password.length >= 6
      return [:error, "Password too short"]
    end

    auth_result = authenticate(cleaned_username, cleaned_password)
    unless auth_result.present?
      return [:error, "Wrong username or password"]
    end

    [:ok, auth_result.access_token]
  end

  private

  attr_reader :username, :password, :cleaned_username, :cleaned_password

  def cleaned_username
    @cleaned_username ||= username.to_s.downcase
  end

  def cleaned_password
    @cleaned_password ||= password.to_s
  end
end
```

In this sample, we need to store `username`, `password` as instance variables, together with `cleaned_username`, `cleaned_password` as Ruby-style caching. During the main call, we attempt a bunch of validations and make early quit as soon as possible. But when more validations are added, it's getting difficult to keep track what the useful pieces of information are. It's quite easy to get distracted by error paths (and line-breaks) because it appears before the happy path.

Railway uses an approach that let readers focus on the happy path before dealing with errors that can happen. It can be used without defining instance variables at all. Let's see below

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

Railway does not have any early quit (aka no `return`), thus it can deal with error paths later. Furthermore, all Railway variables are simple local variables, so that they can be de-allocated sooner than the typical approach.

Bonus: Using Railway can transform your service objects (such as `LoginService` above) into pure functions, because it does not need any instance variable at all! See the full example below:

```ruby
  class LoginService
    extend Railway

    def self.call(username, password)
      with { username.downcase }.as var(:cleaned_username)
        .when { cleaned_username.index( /[^[:alnum:]]/ ) == nil } # No special character
        .then { password.to_s }.as var(:cleaned_password)
          .when { cleaned_password.length >= 6 } # Password minimum length required
          .then { authenticate(cleaned_username, cleaned_password) }.as var(:auth_result)
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
  end
```

## Caveats

## Note on Patches/Pull Requests

* Fork the project.
* Make your feature addition, maintenance or bug fix.
* Add tests for it. This is important so I don't break it in a future version unintentionally.
* Commit, but please do not mess with the gemspec, `VERSION`, `LICENSE`.
* Send me a pull request.
