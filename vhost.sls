include:
  - nginx-ng

# Make sure /var/www/vhosts exists - we don't makedirs later because we want 
# to set root owned explicitly
/var/www/vhosts:
  file.directory:
    - user: root
    - group: root
    - mode: 755

# Loop over sites defined in pillar
{% for site, site_options in salt['pillar.get']('sites', {}).iteritems() %}

# Make sure nginx is a member of the group
group-{{site}}:
  group.present:
    - name: {{site}}
    - addusers:
      - nginx
    - watch_in:
      - service: nginx

# Get nginx port
{% set port = site_options.port %}

# Loop over instances
{% for instance, instance_opts  in pillar['sites'][site]['instances'].iteritems() %}

# Instance-specific settings
  # Set main address from pillar, default to f1 address if not set
  {% if instance_opts['main_address'] is defined %}
    {% set main_address = instance_opts['main_address'] %}
  {% else %}
    {% set main_address = 'None' %}
  {% endif %}

  # Set default of instance.site.forumone.com (www.example.forumone.com)
  {% set f1_address = instance + '.' + site + '.forumone.com' %}

  # Set any aliases for the site
  {% if instance_opts['aliases'] is defined %}
    {% set aliases = instance_opts['aliases'] %}
  {% else %}
    {% set aliases = 'None' %}
  {% endif %}

  # Set any whole-domain redirects
  {% if instance_opts['redirect_from'] is defined %}
    {% set redirect_from = instance_opts['redirect_from'] %}
  {% else %}
    {% set redirect_from = 'None' %}
  {% endif %}

# Add HTTP auth if requested
  {% if instance_opts['auth'] is defined %}
    {% set auth = instance_opts['auth'] %}

htpasswd{{site}}{{instance}}:
  webutil.user_exists:
    - name: {{ instance_opts['auth']['user']}}
    - password: {{ instance_opts['auth']['pass'] }}
    - htpasswd_file: /etc/nginx/conf.d/{{site}}.{{instance}}.htpasswd

  {% else %}
    {% set auth = 'None' %}
  {% endif %}


# Site type - defines base template
/etc/nginx/conf.d/{{site}}.{{instance}}.conf:
  file.managed:
{% if pillar['sites'][site]['type'] == 'drupal' %}
    - source: salt://nginx-ng/files/vhosts/drupal.conf
{% endif %}
{% if pillar['sites'][site]['type'] == 'wordpress' %}
    - source: salt://nginx-ng/files/vhosts/wordpress.conf
{% endif %}
    - template: jinja
    - watch_in:
      - service: nginx
    - require:
      - sls: fpmstack.pools
    - context:
        site: {{ site }}
        instance: {{ instance }}
        main_address: {{ main_address }}
        f1_address: {{ f1_address }}
        port: {{ port }}
        redirect_from: {{ redirect_from }}
        site_root: {{site}}.{{instance}}
        aliases: {{ aliases }}
        auth: {{ auth }}

# Create site directories
/var/www/vhosts/{{site}}.{{instance}}:
  file.directory:
    - user: {{ site }}
    - group: {{ site }}
    - mode: 2770

{% endfor %} # For each instance
{% endfor %} # For each site defined
