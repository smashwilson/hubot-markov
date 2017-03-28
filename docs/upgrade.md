# From 1.x

To upgrade from hubot-markov 1.x:

* Set `HUBOT_MARKOV_STORAGE` to `redis`.
* Set `HUBOT_MARKOV_STORAGE_URL` to the connection URL of your Redis instance. The default is `redis://localhost`.
* If you have `HUBOT_MARKOV_NOREVERSE` set, change it to `HUBOT_MARKOV_REVERSE_MODEL` with the _opposite value_ instead.
