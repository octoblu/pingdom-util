#!/usr/bin/env node

require('coffee-script/register');
var Command = require('./command-configure.coffee');
var command = new Command(process.argv);
command.run();
