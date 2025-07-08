### DEV
1. ``cp .env.example .env``
2. Setup .env values for current user UID GUID
3. ``docker compose up -d``
4. Setup APP_ENV=production for better error handling experience (on local env error stacktrace may be bloated)
5. Go to http://127.0.0.1:9000

#### Optional
Setup project icon in PhpStorm
```
make init
```
#### Setup Xdebug in PHPStorm
1. Go to settings Ctrl+Alt+S -> PHP->Servers hit a button "+"
2. Setup server name site.test (or change env variable in .env and set your value)
3. For address use http://127.0.0.1 port 9000
4. Setup mapping use path for app root in container /var/www/html
5. Apply settings, run debug listeners and add breakpoints, you are awesome =)

#### Testing
``composer test``

#### Linters
```
composer lint
```

Laravel Setup By [Andrey Gurkovskiy](https://t.me/easyitomsk)

### Production
...

(comming soon)
