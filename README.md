---
slug: "using_fragment_caching"
type: "tutorial"
title: "Using Fragment Caching in Rails"
description: "Learn how to load your views faster by caching them"
author_github_nickname: "progapandist"
category: "rails"
---

> "There are only two hard things in Computer Science: cache invalidation and naming things."  
— Old programming wisdom

# Make your views load faster with Rails Fragment Caching

## Intro

Have you ever heard the phrase "_time to glass_"? That's a UX term describing the amount of time it takes for an application to render something on screen (literally: put behind the glass) after the user takes action. Computer scientists started measuring the acceptable rates of interface "lag" as early as [in 1960s](http://theixdlibrary.com/pdf/Miller1968.pdf), way before the web even appeared. Long story short, the golden standard for a web-page load is __1 second__, or 1000 milliseconds. Take longer, and you start losing your audience. So everything that Rails (or any other web framework) usually has to do: receive client's HTTP request, route it to appropriate controller and action, grab data from the database, build a necessary view and send compiled assets back to client in as few HTTP responses as possible — all that should happen before you can even pronounce  "thousand milliseconds".

We hope that by now you formed a habit to study Rails logs and here's what you can see after each request:

```sh
Completed 200 OK in 586ms (Views: 543.1ms | ActiveRecord: 7.3ms)
```

You see now that views usually take considerably more time then a DB query (your mileage may wary depending on machine). Can we do something about it? Yes! Let's learn how to cache dynamic parts of our views so they are not rebuilt from scratch each time a client requests them.

## Sample project

First, let's quickly build a 2-model app that uses __1-n__ relationship between Language and Review (yes, we'll take a break from a long-standing tradition of using French fine dining as an example). In this app, we will catalog programming languages that you have learned at Le Wagon and allow users to review them. Now you can finally express all those feelings you have for CSS!

After we are done with the basics, we will learn to render our views more efficiently by using the power of caching.

Let's start from a [Minimal](https://github.com/lewagon/rails-templates) template:

```sh
$ rails new \
  -T --database postgresql \
  -m https://raw.githubusercontent.com/lewagon/rails-templates/master/minimal.rb \
  languages-cached
```

An app is not an app without some models. In our case, Language and Review, let's generate them:

```sh
$ rails g model Language name description
$ rails g model Review content:text language:references
$ rails db:migrate
```

Our model files will be pretty basic: let's just add a `has_many` association that is not enabled by Rails by default and a basic validation for Review:

```ruby
# review.rb
class Review < ApplicationRecord
  belongs_to :language
  validates :content, length: { minimum: 10 }
end

# language.rb
class Language < ApplicationRecord
  has_many :reviews
  validates :name, :description, presence: true
end
```


Now let's put in some seeds, right from the start, as the importance of a good seed file can never be underestimated. Pick them up from this [gist](https://gist.github.com/progapandist/83477700779ed6541e11d496544f6027) and paste into your `seeds.rb`. You know what happens next: `rails db:seed`.

Let's take care of our routes:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  root to: 'languages#index'
  resources :languages, only: [ :index, :show ] do
    resources :reviews, only: [ :create ]
  end
  resources :reviews, only: [ :destroy ]
end
```

As you can see, we will only allow users to add and delete reviews.

Controller's time!

```sh
$ rails g controller languages
```

```ruby
# app/controllers/languages_controller.rb
class LanguagesController < ApplicationController
  def index
    @languages = Language.all
  end

  def show
    @language = Language.find(params[:id])
    @review = Review.new
  end
end
```

Our "Add review" form will be embedded into a language's `show`. Makes sense.

```sh
$ rails g controller reviews
```

```ruby
# app/controllers/reviews_controller.rb
class ReviewsController < ApplicationController
  def create
    @review = Review.new(review_params)
    @language = Language.find(params[:language_id])
    @review.language = @language
    if @review.save
      redirect_to @review.language
    else
      render 'languages/show'
    end
  end

  def destroy
    @review = Review.find(params[:id])
    @review.destroy
    redirect_to @review.language
  end

  private

  def review_params
    params.require(:review).permit(:content)
  end
end
```

Great! Time to handle our views. First, the index:

```html
<!-- app/views/languages/index.html.erb -->
<div class="container">
  <h1>Languages used at Le Wagon</h1>
  <%= render @languages %>
</div>
```

I know you expected a loop here. Sorry to disappoint you! Time to learn another spell of _Rails Magic_. If you pass a collection to a `render` call, Rails will look for a partial called `_member.html.erb` (in our case, `_language.html.erb`) in the same folder as the parent view and will do all the necessary looping behind the scenes for you. As a bonus, from inside of `_language.html.erb` you can safely call `language` to reference each element in the collection, without passing any _locals_ to a `render` call.   

You'll see in a moment that it works with associated children too. Let's give Rails that partial:

```erb
<!-- app/views/languages/_language.html.erb -->
<h4><%= link_to language.name, language %></h4>
<p><%= language.description %></p>
```

So it will work exactly in the same fashion as if you'd done:

```erb
<div class="container">
  <h1>Languages used at Le Wagon</h1>
  <% @languages.each do |language| %>
    <h4><%= link_to language.name, language %></h4>
    <p><%= language.description %></p>
  <% end %>
</div>
```

Awesome, right? Your views are now much cleaner and the file organization makes more sense. If this seems like a bit too magical, you can read more about it [in Rails guides](http://guides.rubyonrails.org/layouts_and_rendering.html#using-partials), just look for _"3.4.5 Rendering Collections"_, there are more things you can do with collection partials!

Now it's time to do our `show.html.erb` view:

```erb
<div class="container">
  <p style="margin-top: 30px;">
    <%= link_to "Back", languages_path, class: "btn btn-primary" %>
  </p>
  <h1><%= @language.name %></h1>
  <p><%= @language.description %></p>

  <h4>Reviews:</h4>
  <ul>
    <%= render(@language.reviews) || "No reviews yet... Add your own!" %>
  </ul>

  <%= simple_form_for [@language, @review] do |f| %>
    <%= f.input :content %>
    <%= f.submit class: "btn btn-primary" %>
  <% end %>
</div>
```

As you can see, we are using the same collection partial trick as with our languages. We also use the logical operator `||` for yet another trick: if the collection turns out to be empty (no reviews for our language), the `render(@language.reviews)` (note that in this case parenthesis are required) will return `nil` and the right-side of `||` operator will be used, which is a string asking user to add the first review.

Also, Rails is smart enough to look for `_review.html.erb` partial not in the `views/languages` folder, but in `views/reviews`, where it logically belongs. Let's create one:

```erb
<!-- app/views/reviews/_review.html.erb -->
<li>
  <%= review.content %>
  <%= link_to "Delete", review, method: :delete, class: "btn btn-sm btn-danger" %>
</li>
```

Now when everything is in its right place, time to run `rails s` and make sure our core functionality is there.

## Caching

Well, why do we need caching? Let's be frank: for a simple 2-model app the answer is: you don't. However, imagine that you have more than two models and your views are littered with partials, which is something that will surely happen once your project grows. Think of it like that: cramming all ERB code into one view makes your code terribly unmaintainable and prone to bugs (and good luck keeping that indentation!), so the only sane answer to overgrown ERBs is breaking them down into partials (by now you should stick to a simple rule: _every iterative code should be in its own partial_). But partials have their own downside: it takes __time__ for Rails to put together snippets of code coming from many different places. Solution gives us another problem, so... we need another solution and that solution is called __fragment caching__. There are different kinds of caching in Rails, and you should read all about them in an official [Rails guide](http://guides.rubyonrails.org/caching_with_rails.html). We are sticking only to __fragment caching__ in this tutorial.

In essence, a cached fragment (one or several partials, or even a whole view) will be written directly to memory (or a key-value store such as Redis, we will use it in production) once it's constructed for the first time and will be served from memory on all future requests (until properties of underlying objects change and the cache is __invalidated__).

First, let's examine what happens in your back end before you turn caching on (by default it's off in production environment). Fire up your browser and go to a show view of any language. Now study Rails logs in the server's terminal window:

```bash
Processing by LanguagesController#show as HTML
  Parameters: {"id"=>"25"}
  Language Load (0.3ms)  SELECT  "languages".* FROM "languages" WHERE "languages"."id" = $1 LIMIT $2  [["id", 25], ["LIMIT", 1]]
  Rendering languages/show.html.erb within layouts/application
  Review Load (0.3ms)  SELECT "reviews".* FROM "reviews" WHERE "reviews"."language_id" = $1  [["language_id", 25]]
  Rendered collection of reviews/_review.html.erb [4 times] (3.6ms)
  Rendered languages/show.html.erb within layouts/application (97.2ms)
Completed 200 OK in 586ms (Views: 543.1ms | ActiveRecord: 7.3ms)
```

Rails obediently tells you how many times it rendered a `_review.html.erb` partial and how much time it took. If you keep refreshing the page, both values will become smaller, as ActiveRecord will cache the result of the previous query and assets in views will be partially cached by a browser. Let's enable caching server-side! Open your terminal on a project's folder and type this:

```bash
$ rails dev:cache
```

You should see "_Development mode is now being cached_". Your server will restart automatically. However, there would be no way to tell whether the cache is actually used or not, until you manually enable logging (it's new for Rails 5.1). Go to `config/environments/development.rb` and find these lines:

```ruby
# Enable/disable caching. By default caching is disabled.
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true # ADD FOR LOGGING!
    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.seconds.to_i}"
    }
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end
  ```

Add a line `config.action_controller.enable_fragment_cache_logging = true`. However, if you keep reloading a page, nothing will happen, as we need to __tell__ Rails which parts of which views we want to cache. Let's start with a smallest part — our `_review.html.erb` partial. All you need to add is `cache` block around your ERB code:

```
# app/views/reviews/_review.html.erb
<% cache review do %>
<li>
  <%= review.content %>
  <%= link_to "Delete", review, method: :delete, class: "btn btn-sm btn-danger" %>
</li>
<% end %>
```

Now go to your language's show page and add a review, then study logs:

```bash
Started GET "/languages/22" for 127.0.0.1 at 2017-09-24 12:36:55 +0200
Processing by LanguagesController#show as HTML
  Parameters: {"id"=>"22"}
  Language Load (1.4ms)  SELECT  "languages".* FROM "languages" WHERE "languages"."id" = $1 LIMIT $2  [["id", 22], ["LIMIT", 1]]
  Rendering languages/show.html.erb within layouts/application
  Review Load (0.5ms)  SELECT "reviews".* FROM "reviews" WHERE "reviews"."language_id" = $1  [["language_id", 22]]
...
Write fragment views/reviews/43-20170924103655150018/f505202881f1468fba07f32e2cd60b7c (3.2ms)
  Rendered collection of reviews/_review.html.erb [5 times] (30.6ms)
  Rendered languages/show.html.erb within layouts/application (73.8ms)
Completed 200 OK in 139ms (Views: 131.3ms | ActiveRecord: 2.0ms)
```

Finally, something new is happening! We made two SQL queries (to GET the page after we POSTed a new review): one to grab a language, another for associated reviews, and you can see that Rail effectively __writes__ a fragment to memory. After you refresh the page, there will be no writes and only reads — for all existing fragments. Note that the fragment is stored under `views/reviews/43-20170924103655150018/f505202881f1468fba07f32e2cd60b7c`. Note that stamps are unique for all fragments. There is something smart going on under the hood: `43` stands for the ID of a review in the database and `20170924103655150018` is a timestamp generated from its `updated_at` property. Now, whenever an underlying object changes, Rails will know to invalidate the existing cache and write a new key to memory. That magic is possible because we passed our object (an instance of review) to the `cache` method call: `<% cache review do %>`.

Time to admit: we did not gain much by caching **just** the partial, as our partial is not that complicated in the first place, it's one line of code! What if we cache the whole collection of partials on the `show` view of a langugage? Same logic here:

```erb
<% cache @language do %>
  <h1><%= @language.name %></h1>
  <p><%= @language.description %></p>

  <h4>Reviews:</h4>
  <ul>
    <%= render(@language.reviews) || "No reviews yet... Add your own!" %>
  </ul>
<% end %>
```

Note that we need __always need to pass some object__ to `cache` method. We chose `@language`, because we are in `languages#show`. You know the drill: test in a browser, read logs:

```bash
Started GET "/languages/24" for 127.0.0.1 at 2017-09-24 13:41:32 +0200
Processing by LanguagesController#show as HTML
  Parameters: {"id"=>"24"}
  Language Load (0.6ms)  SELECT  "languages".* FROM "languages" WHERE "languages"."id" = $1 LIMIT $2  [["id", 24], ["LIMIT", 1]]
  Rendering languages/show.html.erb within layouts/application
Read fragment views/languages/24-20170924113723884082/10f205aa5fe53d1d131cfa8a68a4f593 (1.3ms)
  Review Load (0.4ms)  SELECT "reviews".* FROM "reviews" WHERE "reviews"."language_id" = $1  [["language_id", 24]]
Read fragment views/reviews/27-20170913192128379586/f505202881f1468fba07f32e2cd60b7c (1.5ms)
Read fragment views/reviews/29-20170913192128382299/f505202881f1468fba07f32e2cd60b7c (2.2ms)
Read fragment views/reviews/38-20170914104857866900/f505202881f1468fba07f32e2cd60b7c (1.8ms)
Read fragment views/reviews/45-20170924113629614601/f505202881f1468fba07f32e2cd60b7c (2.5ms)
  Rendered collection of reviews/_review.html.erb [4 times] (14.6ms)
Write fragment views/languages/24-20170924113723884082/10f205aa5fe53d1d131cfa8a68a4f593 (1.4ms)
  Rendered languages/show.html.erb within layouts/application (37.9ms)
Completed 200 OK in 72ms (Views: 64.9ms | ActiveRecord: 1.0ms)
```

Now you can see that the a new type of fragment is being saved in memory: one for `views/languages`. Reload the page and see that now the output is much shorter:

```bash
Started GET "/languages/24" for 127.0.0.1 at 2017-09-24 13:44:18 +0200
Processing by LanguagesController#show as HTML
  Parameters: {"id"=>"24"}
  Language Load (0.4ms)  SELECT  "languages".* FROM "languages" WHERE "languages"."id" = $1 LIMIT $2  [["id", 24], ["LIMIT", 1]]
  Rendering languages/show.html.erb within layouts/application
Read fragment views/languages/24-20170924113723884082/10f205aa5fe53d1d131cfa8a68a4f593 (4.8ms)
  Rendered languages/show.html.erb within layouts/application (62.0ms)
Completed 200 OK in 117ms (Views: 109.9ms | ActiveRecord: 0.4ms)
```

Note that we also saved ourselves an SQL query: the fragment for a language has a "snapshot" of all associated reviews at the time of cache-write so we don't need to talk to `"reviews"` table anymore. Our cached fragments for `_review` partials are cached under a larger fragment that has to do with their parent record. That is called __Russian Doll Caching__ :)

![Russian dolls](http://www.tobar.co.uk/media/catalog/product/cache/1/image/9df78eab33525d08d6e5fb8d27136e95/E19354_800.jpg)

Russian dolls look cute, but it is __very easy to shoot yourself in a foot using this technique__. Actually, you already did :(. Go to the cached page and try to add or delete a comment. What's going on? Right, nothing changes. If you are not mindful about one important detail, these kind of bugs can drive you absolutely crazy. So, we changed the collection of children for a language, but our cache name is still derived __from the parent object__. There is currently no way for a parent to know that it suddenly got more (or less) children, or if any of the existing children had been modified. Here comes a subtle feature of ActiveRecord. Go to `review.rb` and change one line of code:

```ruby
class Review < ApplicationRecord
  belongs_to :language, touch: true # Let the parent know something changed!
  validates :content, length: { minimum: 10 }
end
```

`touch: true` means that each time there will be a change to a child record, parent's `updated_at` attribute will also change. That will be enough for Rails to bust the cache and write a new fragment. Simple as that!

One last thing. As Rails Guide [tells us](http://guides.rubyonrails.org/caching_with_rails.html#fragment-caching) it is always a good idea to use `cached: true` option when rendering a _"collection"_ partial. In version 5.1 logs you won't see the difference, but with this option being on, Rails will retrieve all partials in one take, instead of one by one. Here's the final code for `show.html.erb`:

```erb
<div class="container">
  <p style="margin-top: 30px;"><%= link_to "Back", languages_path, class: "btn btn-primary" %></p>

  <% cache @language do %>
    <h1><%= @language.name %></h1>
    <p><%= @language.description %></p>

    <h4>Reviews:</h4>
    <ul>
      <%= render(@language.reviews, cached: true) || "No reviews yet... Add your own!" %>
    </ul>
  <% end %>

  <%= simple_form_for [@language, @review] do |f| %>
    <%= f.input :content %>
    <%= f.submit class: "btn btn-primary" %>
  <% end %>
</div>
```

You can change the `index` in the same fashion:

```erb
<div class="container">
  <% cache @languages do %>
    <h1>Languages used at Le Wagon</h1>
    <%= render @languages %>
  <% end %>
</div>
```

Voila! Now all your views are cached and rendered more efficiently!

## Production with Heroku

Strictly speaking, we rarely need caching in development, as a developer you can wait few milliseconds for a page to load. It is the production environment where caching is essential. So as soon as you learned to play around with fragment caching, you can turn it off in development exactly the way you turned it on:

```bash
$ rails dev:cache
```

Time to prepare our production environment. In development, we used the default Rails `:memory_store` as the place for our cached views, for production we will use [Redis](https://redis.io/) to hold our cache. We will also use [Redis Cloud](https://devcenter.heroku.com/articles/rediscloud) Heroku add-on. Before we do any deployment, let's do some preparation.

Add a new gem to your Gemfile and `bundle install`:

```ruby
# Gemfile
gem 'redis-rails'
```

Now we need to create an initializer for Redis in our `config/initializers`. Remember, all code in this folder will execute each time Rails starts, and our `redis.rb` will give us an easy way to connect to our Redis instance by declaring a global variable accessible from anywhere inside our app (console included):

```bash
$ touch config/initializers/redis.rb
```

```ruby
# config/initializers/redis.rb
$redis = Redis.new
$redis = Redis.new(url: ENV["REDISCLOUD_URL"]) if ENV["REDISCLOUD_URL"]
```

Next, we need to add some config to our `production.rb` (insert these lines anywhere in the file):

```ruby
# config/environments/production.rb
if ENV['REDISCLOUD_URL']
  config.cache_store = :redis_store, ENV['REDISCLOUD_URL'], { expires_in: 1.day }
  config.action_controller.enable_fragment_cache_logging = true # you can remove this line once you made sure caching works on Heroku
end
```

You can pass any value to `expires_in` as long as it follows Rails time interval format. One day is sensible enough, as we don't want to keep our fragments in memory forever. Now we are ready to create a Heroku instance and deploy.

```bash
$ git add . && git commit -m "prepare to deploy"
$ heroku create YOUR_APP_NAME
```

Now, just before we push, let's add Redis Cloud as an add-on:

```bash
$ heroku addons:create rediscloud
```

Continue as usual:

```bash
$ git push heroku master
$ heroku run rails db:migrate
$ heroku open
```

Now if you poke around the project and study logs (`heroku logs -t`), you will see some familiar logging for fragments. If it starts to bother you, you can turn it off in `production.rb` by removing a respective line. You can always check the contents of your Redis instance by running `heroku run rails c` and executing `$redis.keys`. If you want to manually delete all cache from Heroku, you can call `$redis.flushall`.

__Congratulations! You have completed the tutorial, feel free to adapt fragment caching to your own projects!__


## When do I need caching again?

Fragment caching is not a silver bullet, and you probably should not bother with it before your views take more than 1000 ms to load. However, if you have a complicated view that uses a lot of iteration over associated models (especially is the associations are nested few levels), it is probably worth considering caching right from the start.

---

Happy caching!
