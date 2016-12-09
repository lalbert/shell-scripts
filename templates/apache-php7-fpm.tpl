<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName {{domain}}
    ServerAlias www.{{domain}}

    <FilesMatch \.php$>
      SetHandler proxy:unix:/run/php/php7.0-fpm.{{user}}.sock|fcgi://127.0.0.1:9001
    </FilesMatch>

    DocumentRoot {{web_root}}
    <Directory {{web_root}}>
            Options -Indexes
            AllowOverride All
            Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/{{user}}_error.log

    # Possible values include: debug, info, notice, warn, error, crit,
    # alert, emerg.
    LogLevel warn

    CustomLog ${APACHE_LOG_DIR}/{{user}}_access.log combined
</VirtualHost>
