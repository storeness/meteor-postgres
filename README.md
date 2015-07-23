# Fork of [Meteor-Postgres](http://www.meteorpostgres.com/)

### Improvements

- Proper support for string IDs


### Installation

Run the following from your command line.

```
    meteor add storeness:meteor-postgres
```

or add this to your `package.js`

```
    api.use('storeness:meteor-postgres');
```

### Tests

To run the test execute the following from your command line.

```
MP_POSTGRES=postgres://{YOUR USERNAME ON THE MACHINE}:numtel@localhost:5439/postgres JASMINE_SERVER_UNIT=1 VELOCITY_TEST_PACKAGES=1 meteor --port 4000 test-packages --driver-package velocity:html-reporter storeness:meteor-postgres
```

and check on [localhost:4000](http://localhost:4000)

### Usage

* [Getting Started](https://github.com/meteor-stream/meteor-postgres/wiki/Getting-Started)
* [Full List of Database Methods](https://github.com/meteor-stream/meteor-postgres/wiki/Database-Methods)
* [Demo Todo App](http://todopostgres.meteor.com/)
* [Refactor from Mongo to PostgreSQL](https://www.youtube.com/watch?v=JwHfxJnD0Yc)

### Implementation

We used [Node-Postgres](https://github.com/brianc/node-postgres) on the server and [AlaSQL](https://github.com/agershun/alasql) on the client.

### License

Released under the MIT license. See the LICENSE file for more info.
