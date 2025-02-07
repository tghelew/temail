CREATE OR REPLACE VIEW  v_sogo_users AS
       WITH aliases AS (
            SELECT
                goto as username
                ,string_agg(address, ' ') as aliases
            FROM
                alias
            WHERE
                active = 't'
                AND goto != address
            GROUP BY goto

       )
       SELECT
        m.local_part AS c_uid
        ,m.username as mail
        ,m.username AS c_name
        ,m.password AS c_password
        ,m.domain AS c_domain
        ,m.name  AS c_cn
        ,COALESCE(a.aliases,'') AS c_aliases
       FROM
        mailbox m
       LEFT  JOIN aliases a ON a.username = m.username
       WHERE
        active = 't';

GRANT SELECT ON v_sogo_users TO sogo;

CREATE OR REPLACE VIEW  v_sogo_users_ghelew_ch AS
       SELECT
        c_uid
        ,mail
        ,c_name
        ,c_password
        ,c_domain
        ,c_cn
        ,c_aliases
       FROM
        v_sogo_users
       WHERE
        c_domain = 'ghelew.ch';

GRANT SELECT ON v_sogo_users_ghelew_ch TO sogo;


CREATE OR REPLACE VIEW  v_sogo_users_ghedesei_ch AS
       SELECT
        c_uid
        ,mail
        ,c_name
        ,c_password
        ,c_domain
        ,c_cn
        ,c_aliases
       FROM
        v_sogo_users
       WHERE
        c_domain = 'ghedesei.ch';

GRANT SELECT ON v_sogo_users_ghedesei_ch to SOGO;
