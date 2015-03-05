# Nginx state for pillar-defined virtual hosts and common 
# core config

# Package, service, role
nginx:
  pkg:
    - installed
  service:
    - enable: True
    - running
    - require:
      - pkg: nginx
  grains.list_present:
    - name: roles
    - value: nginx

# For htpasswd management
httpd-tools:
  pkg.installed

# Common config tree
/etc/nginx:
  file.recurse:
    - source: salt://nginx-ng/files/nginx/
    - template: jinja
    - user: root
    - group: root
    - include_empty: True
    - watch_in:
      - service: nginx
