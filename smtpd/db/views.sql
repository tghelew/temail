CREATE OR REPLACE VIEW  v_smtpd_alias AS
       WITH virtuals AS (
            SELECT
             address
             ,'vmail' AS goto
            FROM
                alias
            WHERE
                address = goto
                and active = 't'
            UNION
            SELECT
                address
                ,goto
            FROM
                alias
            WHERE
                address != goto
                and active = 't'
        )
        SELECT address, goto FROM virtuals;

CREATE OR REPLACE VIEW  v_smtpd_mailbox AS
       SELECT
            username
            , REPLACE(password, '$2y$', '$2b$') AS password
       FROM
            mailbox
        WHERE
            active = 't';

CREATE OR REPLACE VIEW  v_smtpd_domain AS
       SELECT
            domain
       FROM
            domain
        WHERE
            active = 't'
            AND domain != 'ALL';


CREATE OR REPLACE VIEW  v_smtpd_addrmap AS
       SELECT
            address
            , goto
       FROM
            alias
        WHERE
            active = 't';
