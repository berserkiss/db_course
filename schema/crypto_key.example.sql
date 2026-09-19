-- The key pkg_crypto_utils encrypts with. Copy this file to
-- schema/crypto_key.sql, put a real key in it, and run it after the tables
-- exist and before anything is encrypted. crypto_key.sql is gitignored.
--
-- Generate a 256-bit key:
--     openssl rand -base64 32
--
-- Changing this key makes every value already encrypted with the old one
-- unreadable, including the ciphertext in data/users.json. Rotating it
-- means re-seeding and re-exporting, not just editing this line.

INSERT INTO crypto_config (key_name, key_value)
VALUES ('DATA_KEY', 'REPLACE_ME_WITH_openssl_rand_base64_32');
COMMIT;
