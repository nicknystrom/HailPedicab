if (process.env.NODE_ENV == 'production')
{
	module.exports = require('./.build/app');
}
else
{
	require('coffee-script');
	module.exports = require('./app')
}
