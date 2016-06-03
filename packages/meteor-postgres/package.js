Package.describe({
  name: 'storeness:meteor-postgres',
  version: '0.2.2',
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
  api.use('check');
  api.use('tracker');
  api.use('ddp');
  api.use('agershun:alasql@0.2.0');

  api.addFiles([
    'lib/init.js',
    'lib/sql.coffee'
  ], ['client', 'server']);

  api.addFiles([
    'lib/client.coffee'
  ], 'client');

  api.addFiles([
    'lib/server.coffee'
  ], 'server');

  api.addFiles([
    'lib/collection.coffee'
  ]);

  api.export('SQL');
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
    'tests/jasmine/collectionSpec.coffee'
  ]);

  api.addFiles([
    'tests/jasmine/client/clientSpec.coffee'
  ], 'client');

  api.addFiles([
    'tests/jasmine/server/serverSpec.coffee'
  ], 'server');
});
