# Year in Pictures

Photos of the year.

Built using [PureCSS](https://pure-css.github.io/) using Jekyll and Sqlite3. Requires a Ruby environment with Bundler installed and appropriate native Sqlite3 bindings / support. Image optimisation is done with `jpegoptim`. Up-to-date YAML is stored in this repo, but Rake task to udpate with new entries requires a [YiP Rails helper](https://github.com/tomnatt/year-in-pictures-rails-helper) running with location configured in and environment variable, or direct editing of YAML in `/_db/data`.

## Image sizes

Main images are 1020px wide. Thumbnails are 190px x 190px.

## Environment variables

Image copying:
* `YIP_IMAGE_SOURCE_DIR` - copy images and thumbnails from here (thumbnails stored as `YIP_IMAGE_SOURCE_DIR/thumbnails`)

Deployment:
* `HOSTING_USER` - remote server user
* `YEARINPICTURES_HOSTING_DIR` - remote server deploy location
* `DEPLOY_TARGET` - remote server location

Link to YiP Rails helper:
* `YIP_RAILS_HELPER_LOCATION` - base URL for helper
* `YIP_YEAR_TOKEN_PROD` - API key to access data

## Installation
> _This section assumes you're familiar with Ruby and have a working local development environment already available to you, preferably *nix-based. For a suggestion of how to setup and run Ruby projects easily under Windows, see **Appendix A**._

1. Clone to your chosen directory
1. `bundle install`
1. `bundle exec rake db_create db_add_all_pictures`
1. `bundle exec rake serve`
1. http://localhost:4000/

SCSS files are in `/_assets`.

To actually build the site from the command line, run:

```
bundle exec rake
```

## Testing

Tests are based on [RSpec](https://rspec.info/) and can be found in `/spec`.

To run the test suite:

```bundle exec rspec```

_Note these were first bootstrapped through Claude Code after a project analysis._

## Credits

The photo stuff started life on [one of the Zurb example pages](http://zurb.com/playground/css3-polaroids).

## To add a new month of pictures

1. Run `bundle exec rake monthly` to download latest YAML, copy pics and optimise, update the database and run checks
1. Update `index.html` with new month
1. Build and check locally with `bundle exec rake serve`
1. Commit changes

## To update for a new year

1. Move `index.html` to `$year.html` (and commit)
1. Add new `index.html` file set up with new year
1. Create new `/$year/thumbnails` directory in `/images`
1. Add new year data block in `/_config/jekyll_config.yml`
1. Add new year in `/_config/years.yml` and rebuild database
1. Check [a short photographer page](http://localhost:4000/photographers/36.html) for length of RH menu
1. Check [photographers page](http://localhost:4000/photographers/) for thumbnails
1. Add January photos as normal

If there are any helper scripts (e.g. in `/bin`) remember to update those too.


<center>~ ✻ ~</center>


## Appendix A: Install and run under Windows
First, you need an environment to run the project within. For the dual benefits of simplicity and compatibility, I would suggest opting for a recent, long-life version of Ubuntu, running under Windows' Subsystem for Linux (WSL).
1. Go to the **Microsoft Store** application in Windows, and install the newest **LTS** version of Ubuntu available (this guide was tested using v24.04).
1. Once Windows Store has done its thing, open an Ubuntu prompt from the Start menu and immediately update Ubuntu's package registry:\
   `sudo apt-get update`
1. Next, install [Ubuntu's Developer Tools](https://launchpad.net/ubuntu-dev-tools) package:\
   `sudo apt-get install ubuntu-dev-tools`\
   ...if you get a shell dialogue asking for a **mirror**, you can safely reference the official repo directly:\
   `https://git.launchpad.net/ubuntu-dev-tools`
1. Still in the Ubuntu prompt, install **Ruby 3.4** and its dependencies:\
   `sudo snap install ruby --channel=3.4/stable --classic`

Before we can build `year-in-pictures` we need to tweak the version of Ruby it expects. The latest stable version of Ruby on Ubuntu is **3.4.8**, but the `year-in-pictures` project is pinned to **3.4.5**. We can safely hack around this, as it's a trivial patch release difference.
1. Open the `year-in-pictures` source code directory in your editor of choice.
1. Find the `.ruby-version` file in the root of the project and edit it to require version `3.4.8` instead.

You're now ready to jump back to the main **Installation** section of this document and continue setup as otherwise expected.
