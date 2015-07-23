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
  api.use('underscore');
  api.use('tracker');
  api.use('ddp');

  // minisql
  api.addFiles(['minisql/alasql.js', 'minisql/alasql.js.map', 'minisql/minisql.js'], 'client');
  api.export('miniSQL', 'client');

  api.addFiles('postgres/serversql.js', 'server');
  api.export('serverSQL', 'server');

  api.addFiles('collection/collection.js');
  api.export('SQL');
});

Package.onTest(function (api) {
  api.use('sanjo:jasmine@0.15.0');
  api.use('coffeescript');
  api.use('spacebars');
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
