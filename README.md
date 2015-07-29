# PostgreSQL + Meteor

Adds postgres support to Meteor via `SQL.Collection`, which is similar to
`Mongo.Collection` and provides the same functionality namely livequery, pub/sub, latency compensation and client side cache.

Still I would not recommend using it in production yet as the ORM layer is open for SQL-injections. You can check out [this SQL package blueprint](https://github.com/storeness/sql) for a
possible more sophisticated SQL implementation that could support most popular SQL
Databases, Models and Migrations.

### Improvements

- Tests
- Proper support for IDs (including strings)
- Cleaner code and API
- Support of underscores in table and column names
- Many bug fixes including
  - errors on creating existent tables (convenient for server startup)
  - postgres client event leak
  - alasql column bug
- Working example

### Installation

Run the following from your command line.

```
    meteor add storeness:meteor-postgres
```

or add this to your `package.js`

```
    api.use('storeness:meteor-postgres');
```

### Usage

To get started you might want to take a look at the [todo-example
code](https://github.com/storeness/meteor-postgres/blob/simple-todo.js). You can run
the code by cloning this repo locally and start it by running
`MP_POSTGRES=postgres://{username}:{password}:{url}:{port}/{database_name}
meteor` inside the cloned directory.

### Tests

To run the test execute the following from your command line.

```
MP_POSTGRES=postgres://{YOUR USERNAME ON THE MACHINE}:numtel@localhost:5439/postgres JASMINE_SERVER_UNIT=1 VELOCITY_TEST_PACKAGES=1 meteor --port 4000 test-packages --driver-package velocity:html-reporter storeness:meteor-postgres
```

and check on [localhost:4000](http://localhost:4000)

### Implementation

We use [Node-Postgres](https://github.com/brianc/node-postgres) on the server and [AlaSQL](https://github.com/agershun/alasql) on the client.
Also thanks to [Meteor-Postgres](http://www.meteorpostgres.com/) as this project
is based on their initial work, but which gets not longer maintained.

### License

Released under the MIT license. See the LICENSE file for more info.
