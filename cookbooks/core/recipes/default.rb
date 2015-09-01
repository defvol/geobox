%w[wget curl ack-grep python-software-properties autoconf bison flex libyaml-dev libtool make vim].each do |pkg|
  package pkg do
    action :install
  end
end

install_prefix = "/usr/local"

["add-apt-repository ppa:ubuntugis/ubuntugis-unstable -y", "apt-get update"].each do |cmd|
  execute cmd do
    user "root"
  end
end

["sudo add-apt-repository ppa:mapnik/nightly-2.0 -y", "apt-get update"].each do |cmd|
  execute cmd do
    user "root"
  end
end

# Geo packages
%w[
  libsqlite3-dev
  libproj-dev
  libgeos-dev
  libspatialite-dev
  libgeotiff-dev
  libgdal-dev
  gdal-bin
  libmapnik-dev
  mapnik-utils
  python-dev
  python-setuptools
  python-pip
  python-gdal
  python-mapnik
  postgresql
  postgresql-contrib
  postgis
  postgresql-9.3-postgis-2.1
  libjson0-dev
  redis-server
  libxslt-dev
  unzip
  unp
  osm2pgsql
  osmosis
  protobuf-compiler
  libprotobuf-dev
  libtokyocabinet-dev
  python-psycopg2
  imagemagick
  libmagickcore-dev
  libmagickwand-dev
].each do |pkg|
  package pkg do
    action :install
  end
end

install_prefix = "/usr/local"


execute "apt-get update" do
  user "root"
end

execute "setup Postgres & PostGIS" do
  command <<-EOS
    if [ ! sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='gisuser'" | grep -q 1 ]
    then
      sudo -u postgres createuser gisuser &&
      sudo -u postgres createdb --encoding=UTF8 --owner=gisuser gis &&
      sudo -u postgres psql -d gis -c 'CREATE EXTENSION postgis; CREATE EXTENSION hstore;' &&
      sudo -u postgres psql -d gis -f /usr/share/postgresql/9.3/contrib/postgis-2.1/postgis.sql &&
      sudo -u postgres psql -d gis -f /usr/share/postgresql/9.3/contrib/postgis-2.1/spatial_ref_sys.sql &&
      sudo -u postgres psql -d gis -f /usr/share/postgresql/9.3/contrib/postgis-2.1/postgis_comments.sql &&
      sudo -u postgres psql -d gis -c "GRANT SELECT ON spatial_ref_sys TO PUBLIC;" &&
      sudo -u postgres psql -d gis -c "GRANT ALL ON geometry_columns TO gisuser;" &&
      ln -sf /usr/share/postgresql-common/pg_wrapper /usr/local/bin/shp2pgsql &&
      ln -sf /usr/share/postgresql-common/pg_wrapper /usr/local/bin/pgsql2shp &&
      ln -sf /usr/share/postgresql-common/pg_wrapper /usr/local/bin/raster2pgsql &&
      sudo /etc/init.d/postgresql restart
    fi
  EOS
  action :run
  user 'root'
end

ENV['PATH'] = "/home/#{node[:user]}/local:#{ENV['PATH']}"

execute "set shell to zsh" do
  command "usermod -s /bin/zsh #{node[:user]}"
  action :run
  user "root"
end

directory "/home/#{node[:user]}/local" do
  owner node[:user]
  group node[:user]
  mode "0755"
  action :create
end

directory "/home/#{node[:user]}/local/src" do
  owner node[:user]
  group node[:user]
  mode "0755"
  action :create
end

directory "#{install_prefix}/src" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

execute "ruby on rbenv" do
  command <<-EOS
    cd &&
    rm -rf .rbenv
    git clone git://github.com/sstephenson/rbenv.git .rbenv &&
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc &&
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc &&
    exec $SHELL &&
    git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build &&
    echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc &&
    exec $SHELL &&
    git clone https://github.com/sstephenson/rbenv-gem-rehash.git ~/.rbenv/plugins/rbenv-gem-rehash &&
    rbenv install 2.2.3 &&
    rbenv install 1.9.3 &&
    rbenv global 1.9.3 &&
    echo "gem: --no-ri --no-rdoc" > ~/.gemrc &&
    gem install bundler
  EOS
  action :run
end

git "oh-my-zsh" do
  repository "git://github.com/robbyrussell/oh-my-zsh.git"
  reference 'master'
  destination "/home/#{node[:user]}/.oh-my-zsh"
  action :checkout
  user node[:user]
end

# install nvm
include_recipe 'nvm'

# install node.js
nvm_install 'v0.12'  do
  from_source false
  alias_as_default true
  action :create
end

execute "install standard node modules" do
  modules = %w(coffee-script underscore node-gyp)
  command modules.map {|m| "npm install -g #{m}" }.join(' && ')
  action :run
  user 'root'
end

# CARTODB

execute "install pip" do
  command "easy_install pip"
  action :run
  user 'root'
end

execute "install imposm" do
  command <<-EOS
    pip install imposm.parser &&
    pip install Shapely &&
    pip install imposm
  EOS
  user 'root'
end

execute "install python dependencies for CartoDB" do
  command <<-EOS
    pip install 'chardet==1.0.1' &&
    pip install 'argparse==1.2.1' &&
    pip install 'brewery==0.6' &&
    pip install 'redis==2.4.9' &&
    pip install 'hiredis==0.1.0' &&
    pip install -e 'git+https://github.com/RealGeeks/python-varnish.git@0971d6024fbb2614350853a5e0f8736ba3fb1f0d#egg=python-varnish==0.1.2'
  EOS
  action :run
  user 'root'
end

git "CartoDB-SQL-API" do
  repository "git://github.com/Vizzuality/CartoDB-SQL-API.git"
  reference 'master'
  destination "#{install_prefix}/src/CartoDB-SQL-API"
  action :checkout
  user "root"
end

execute "setup CartoDB-SQL-API" do
  command "cd #{install_prefix}/src/CartoDB-SQL-API && npm install"
end

git "Windshaft-cartodb" do
  repository "git://github.com/Vizzuality/Windshaft-cartodb.git"
  reference 'master'
  destination "#{install_prefix}/src/Windshaft-cartodb"
  action :checkout
  user "root"
end

execute "setup Windshaft-cartodb" do
  cwd "#{install_prefix}/src/Windshaft-cartodb"
  command <<-EOS
    sudo npm install
  EOS
  user 'root'
end

execute "start Windshaft-cartodb" do
  cwd "#{install_prefix}/src/Windshaft-cartodb"
  command <<-EOS
    mkdir -p log pids
    chown -R vagrant:vagrant log pids
    [ -f pids/windshaft.pid ] && kill `cat pids/windshaft.pid`
    nohup node app.js development >> #{install_prefix}/src/Windshaft-cartodb/log/development.log 2>&1 &
    echo $! > #{install_prefix}/src/Windshaft-cartodb/pids/windshaft.pid
  EOS
  user 'root'
end

git "CartoDB" do
  repository "git://github.com/Vizzuality/cartodb.git"
  reference 'master'
  destination "#{install_prefix}/src/cartodb"
  action :checkout
  user "root"
end

execute "setup cartodb" do
  # strip out the ruby-debug gem from the Gemfile since it consistently causes problems and
  # doesn't seem to install properly in all ruby environments and OS's.
  # also, overwrite `script/create_dev_user` with a custom one that doesn't prompt
  cwd "#{install_prefix}/src/cartodb"
  command <<-EOS
    if [ ! -f config/database.yml ]
    then
      chown -R vagrant:vagrant #{install_prefix}/src/cartodb

      sed 's/.*gem "ruby-debug.*//g' Gemfile > Gemfile.tmp && mv Gemfile.tmp Gemfile
      sed 's/^echo -n "Enter.*//g' script/create_dev_user > script/create_dev_user.tmp && mv script/create_dev_user.tmp script/create_dev_user

      export RY_PREFIX=#{install_prefix} &&
      export PATH=$RY_PREFIX/lib/ry/current/bin:$PATH

      #{install_prefix}/lib/ry/current/bin/bundle install --binstubs &&
      curl -s https://raw.github.com/gist/21c52f1eb9862a1dfffa/58cc1436d23153be0ad2502c8ed5459847c85685/app_config.yml -o config/app_config.yml &&
      curl -s https://raw.github.com/gist/4c503e531fd54b3cbcec/0a435609a58e3f8401cfee5990e173b170e2cc82/database.yml -o config/database.yml &&
      echo "127.0.0.1 admin.localhost.lan"   | tee -a /etc/hosts &&
      echo "127.0.0.1 admin.testhost.lan"    | tee -a /etc/hosts &&
      echo "127.0.0.1 cartodb.localhost.lan" | tee -a /etc/hosts &&
      PASSWORD=cartodb ADMIN_PASSWORD=cartodb EMAIL=admin@cartodb sh script/create_dev_user cartodb
    fi
  EOS
  user "root"
end

execute "start cartodb" do
  cwd "#{install_prefix}/src/cartodb"
  command <<-EOS
    mkdir -p public log tmp pids
    chown -R vagrant:vagrant public log tmp pids
    [ -f pids/cartodb.pid ] && kill `cat pids/cartodb.pid`
    export RY_PREFIX=#{install_prefix}
    export PATH=$RY_PREFIX/lib/ry/current/bin:$PATH
    nohup bundle exec rails server >> #{install_prefix}/src/cartodb/log/development.log 2>&1 &
    echo $! > #{install_prefix}/src/cartodb/pids/cartodb.pid
  EOS
  user 'root'
end
