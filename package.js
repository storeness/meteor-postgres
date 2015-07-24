Package.describe({
  name: 'storeness:meteor-postgres',
  version: '0.1.5',
  summary: 'PostgreSQL support for Meteor',
  git: 'https://github.com/storeness/meteor-postgres',
  documentation: 'README.md'
});

Npm.depends({
  'pg': '4.3.0'
});

Package.onUse(function (api) {
  api.versionsFrom('1.1.0.2');
  api.use('coffeescript');
  api.use('underscore');
  api.use('tracker');
  api.use('ddp');

  api.addFiles('lib/init.js', ['client', 'server']);

  api.addFiles([
    'lib/serversql.coffee'
  ], 'server');

  api.addFiles([
    'lib/collection.js'
  ]);

  api.addFiles([
    'lib/minisql/alasql.js',
    'lib/minisql/alasql.js.map',
    'lib/minisql.js'
  ], 'client');

  api.export('SQL');
  api.export('miniSQL');
  api.export('serverSQL');
});

Package.onTest(function (api) {
  api.use('sanjo:jasmine@0.15.1');
  api.use('coffeescript');
  api.use('spacebars');
  api.use('underscore');
  api.use('storeness:meteor-postgres');

  // Start postgres test-server
  api.use('numtel:pg-server');
  api.addFiles('tests/db-settings.pg.json');

  api.addFiles([
    'tests/jasmine/server/collectionSpec.coffee'
  ]);

  api.addFiles([
    'tests/jasmine/client/minisqlSpec.coffee'
  ], 'client');

  api.addFiles([
    'tests/jasmine/server/serversqlSpec.coffee'
  ], 'server');
});
