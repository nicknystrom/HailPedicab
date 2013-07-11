var app = require('./app');
if (process.env.NODE_ENV != 'production')
{
	app.listen(3000);
}
module.exports = app;
