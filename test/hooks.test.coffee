# Global suite hooks

pgp = require('pg-promise')()

after -> pgp.end()
