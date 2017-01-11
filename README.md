# Garland gem

## Summary

Provides GarlandRails::Base class for ActiveRecord, which allows you to save Hashes using snapshots and diffs (in short, it's HashDiff Rails storage).

## Installing

Add this to your Gemfile

`gem "garland"`

and run

```
bundle install
rails g garland:install
rake db:migrate
```

This will install gem and create `garlands` table in your database (models should be created/adjusted manually).

## Usage

### Simple model

Setup your model:


```
# models/event.rb
class Event < GarlandRails::Base
end
```

Push some hashes:

```
my_event = { where: "here", when: "now" }
Event.push(my_event)
=> #<Event id: 2, entity: "[[\"+\", \":when\", \"now\"], [\"+\", \":where\", \"here\"]]", ... >
# push() always (if succeed) returns record which is latest diff
```

Now, let's look, what happened our model:

```
Event.all
=> #<ActiveRecord::Relation [
#<Event id: 1, entity: "{}", entity_type: false, previous: nil, next: 3, belongs_to_id: nil, belongs_to_type: nil, type: "Event", created_at: "[FILTERED]", updated_at: "[FILTERED]">,
#<Event id: 3, entity: "[[\"+\", \":when\", \"now\"], [\"+\", \":where\", \"here\"]]", entity_type: true, previous: 1, next: 2, belongs_to_id: nil, belongs_to_type: nil, type: "Event", created_at: "[FILTERED]", updated_at: "[FILTERED]">,
#<Event id: 2, entity: "{:where=>\"here\", :when=>\"now\"}", entity_type: false, previous: 3, next: nil, belongs_to_id: nil, belongs_to_type: nil, type: "Event", created_at: "[FILTERED]", updated_at: "[FILTERED]">
]>
```

As you see, `GarlandRails::Base` model now consists of tail (always `{}`, `id=1` here), head (always the latest hash you push, aka snapshot, here it's under `id=2`) and diffs between them (`id=3`).

OK, let's push something else:

```
my_second_event = { where: "here", when: "tomorrow" }
Event.push(my_second_event)
=> #<Event id: 4, entity: "[[\"~\", \":when\", \"now\", \"tomorrow\"]]", entity_type: true, previous: 31, next: 30, belongs_to_id: nil, belongs_to_type: nil, type: "Event", created_at: "[FILTERED]", updated_at: "[FILTERED]">
```

Chain of diffs and snapshots now will look like this:

```
"{}" # "tail"
=>
"[[\"+\", \":when\", \"now\"]
=>
"[[\"~\", \":when\", \"now\", \"tomorrow\"]]"
=>
"{:where=>\"here\", :when=>\"tomorrow\"}" # "head"
```

Cool! (It would be cooler if the diff wasn't larger than the snapshot though.)

### ActiveRecord relations

If you need to Garland records to belong to some other model records, you may use regular Rails `belongs_to/has_many` relations:

```
# models/config.rb
class Config < GarlandRails::Base
  belongs_to :program
end

# models/program.rb
class Program < ActiveRecord::Base
  include GarlandRails::Extend
  has_many :configs
end
```

This will make polymorphic-like relation, storing id and type of relation in `belongs_to_id` and `belongs_to_type` fields of `Config`. Be sure that this won't spoil your other non-garland models' relations.


```
program1 = Program.new(name: "program1")
program1.save
my_config = { path: "path/to/program", url: "example.com", token: "t0ken" }
Config.push(hash: my_config, belongs_to: program1)
=> #<Config id: 2, entity: "[[\"+\", \":path\", \"path/to/program\"], [\"+\", \":token\"...", entity_type: true, previous: 1, next: 3, belongs_to_id: 2, belongs_to_type: "Program", type: "Config", created_at: "[FILTERED]", updated_at: "[FILTERED]">
```

Note `belongs_to_id` and `belongs_to_type` fields.

Now you can use `program1.configs` and other relation features like `dependent: :destroy`!

## Caveats

* `Garland` is intended to be long-term data storage, so there are no abstractions that allows you to get n-th snapshot of your model currently implemented

* there are no more snapshots besides head and tail, so make sure you backup your data (well, I think you should back up it anyway)

## Testing

* prepare db

```
sudo -u postgres psql
create role YOUR_DB_USERNANE with CREATEDB SUPERUSER LOGIN PASSWORD 'YOUR_DB_PASSWORD';
\q
rake db:create
rake db:schema:load
```

* `git clone`
* `bundle install`
* `rake db:test:prepare`

* create `.env` file  in the root and fill it like this

```
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=YOUR_DB_USERNANE
DB_PASSWORD=YOUR_DB_PASSWORD
```

* `rails test`

## TODO

* auto snapshots from time to time *(where to store variables and counters? that's the question!)*
* custom table name *(where to store it? sooo many questions!)*
* savepoints create/rollback/release tests

## License

Garland is distributed under the MIT-LICENSE.
