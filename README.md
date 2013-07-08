AcmeApp
=================

Mobile hail-a-cab app for Acme Pedicabs.

Quick start
-----------

Clone the repo:

```
git clone git@github.com:belay-software/AcmeApp.git
```

Install global dependencies
---------------------------

These steps are typically the same for all nodejs based projects at BelaySoftware, so you can safely skip
them if you've developed a similiar project on your workstation already.

* OSX:
 - Install homebrew from http://mxcl.github.com/homebrew/: `ruby -e "$(curl -fsSL https://raw.github.com/mxcl/homebrew/go)"`
 - `brew install node mongodb redis'`

* Ubuntu:
 - `sudo apt-get install nodejs mongodb redis`

The CoffeeScript package will need to be installed globaly (if you want to run Cake tasks). After node is installed:

```
npm install -g coffee-script`
```

Install local dependencies
--------------------------

Start by having git fetch the various libraries that are used:

```
git submodule init
git submodule update
```

Then use the `npm` utility to load the many nodejs modules that are required:

```
$ npm install
```

Start the server
----------------

Start the server with:

`cake -w run`

Use the `-w` flag to indicate that the all coffee files should be monitored for changes and the server restarted when
changes are detected. This is ideal for the development environment. In production there is no need to use the `-w` flag.

Authors
-------

Nick Nystrom
Anthony Sather

Copyright and license
---------------------

Copyright 2013 Belay Software LLC
Copyright 2013 Acme Pedicabs LLC

Some portions of this work are licensed under various open source terms as indicated, for example
review the license terms in src/public/js/copyright-master.js.