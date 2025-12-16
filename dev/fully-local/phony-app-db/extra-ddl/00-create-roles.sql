CREATE ROLE "testUsername" LOGIN PASSWORD 'testPassword';
CREATE ROLE vdi_w;
CREATE ROLE gus_r;

GRANT vdi_w, gus_r TO "testUsername" WITH INHERIT TRUE;