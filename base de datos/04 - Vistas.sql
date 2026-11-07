
USE torneo_futbol5;

-- Vista del resultado del partido

CREATE OR REPLACE VIEW v_resultado_partido AS
SELECT p.id_partido,
       p.id_torneo,
       p.numero_fecha,
       p.id_equipo_local,
       p.id_equipo_visitante,
       (SELECT COUNT(*)
          FROM gol g
          JOIN planilla_partido pp
            ON pp.id_partido = g.id_partido AND pp.ci_jugador = g.ci_jugador
         WHERE g.id_partido = p.id_partido
           AND ((pp.id_equipo = p.id_equipo_local     AND g.autogol = 0)
             OR (pp.id_equipo = p.id_equipo_visitante AND g.autogol = 1))) AS goles_local,
       (SELECT COUNT(*)
          FROM gol g
          JOIN planilla_partido pp
            ON pp.id_partido = g.id_partido AND pp.ci_jugador = g.ci_jugador
         WHERE g.id_partido = p.id_partido
           AND ((pp.id_equipo = p.id_equipo_visitante AND g.autogol = 0)
             OR (pp.id_equipo = p.id_equipo_local     AND g.autogol = 1))) AS goles_visitante
FROM partido p
WHERE p.estado = 'jugado';

-- Vista de los detalles del partido

CREATE OR REPLACE VIEW v_partido_detalle AS
SELECT p.id_partido, p.id_torneo, p.numero_fecha, p.dia,
       t.hora_inicio, t.hora_fin,
       c.nombre AS complejo, p.nombre_cancha,
       el.nombre AS local, ev.nombre AS visitante,
       p.estado, p.fecha_hora_jugado,
       r.goles_local, r.goles_visitante
FROM partido p
JOIN turno t     ON t.id_turno = p.id_turno
JOIN complejo c  ON c.id_complejo = p.id_complejo
JOIN equipo el   ON el.id_equipo = p.id_equipo_local
JOIN equipo ev   ON ev.id_equipo = p.id_equipo_visitante
LEFT JOIN v_resultado_partido r ON r.id_partido = p.id_partido;

-- Vista de los equipos del partido

CREATE OR REPLACE VIEW v_equipo_partido AS
SELECT id_torneo, id_partido, id_equipo_local AS id_equipo,
       goles_local AS gf, goles_visitante AS gc
FROM v_resultado_partido
UNION ALL
SELECT id_torneo, id_partido, id_equipo_visitante,
       goles_visitante, goles_local
FROM v_resultado_partido;


-- Vista de posiciones

CREATE OR REPLACE VIEW v_tabla_posiciones AS
SELECT RANK() OVER (PARTITION BY x.id_torneo
                    ORDER BY x.puntos DESC, x.diferencia_goles DESC, x.goles_favor DESC) AS posicion,
       x.*
FROM (
  SELECT e.id_torneo, e.id_equipo, e.nombre AS equipo,
         COUNT(ep.id_partido)                                  AS partidos_jugados,
         COALESCE(SUM(ep.gf >  ep.gc), 0)                      AS ganados,
         COALESCE(SUM(ep.gf =  ep.gc), 0)                      AS empatados,
         COALESCE(SUM(ep.gf <  ep.gc), 0)                      AS perdidos,
         COALESCE(SUM(ep.gf), 0)                               AS goles_favor,
         COALESCE(SUM(ep.gc), 0)                               AS goles_contra,
         COALESCE(SUM(ep.gf), 0) - COALESCE(SUM(ep.gc), 0)     AS diferencia_goles,
         COALESCE(SUM(CASE WHEN ep.gf > ep.gc THEN 3
                           WHEN ep.gf = ep.gc THEN 1 ELSE 0 END), 0) AS puntos
  FROM equipo e
  LEFT JOIN v_equipo_partido ep
         ON ep.id_equipo = e.id_equipo AND ep.id_torneo = e.id_torneo
  GROUP BY e.id_torneo, e.id_equipo, e.nombre
) x;


-- Vista del top 10 goleadores

CREATE OR REPLACE VIEW v_goleadores AS
SELECT *
FROM (
  SELECT ROW_NUMBER() OVER (PARTITION BY y.id_torneo
                            ORDER BY y.goles DESC, y.apellido, y.nombre) AS puesto,
         y.*
  FROM (
    SELECT p.id_torneo, j.ci, j.nombre, j.apellido, e.nombre AS equipo,
           COUNT(*) AS goles
    FROM gol g
    JOIN partido p ON p.id_partido = g.id_partido
    JOIN jugador j ON j.ci = g.ci_jugador
    JOIN equipo_jugador_torneo ejt
         ON ejt.ci_jugador = g.ci_jugador AND ejt.id_torneo = p.id_torneo
    JOIN equipo e ON e.id_equipo = ejt.id_equipo
    WHERE g.autogol = 0
    GROUP BY p.id_torneo, j.ci, j.nombre, j.apellido, e.nombre
  ) y
) z
WHERE z.puesto <= 10;


-- Vista de fair play 

CREATE OR REPLACE VIEW v_fair_play AS
SELECT RANK() OVER (PARTITION BY f.id_torneo ORDER BY f.puntos_fair_play ASC) AS posicion,
       f.*
FROM (
  SELECT e.id_torneo, e.id_equipo, e.nombre AS equipo,
         COALESCE(SUM(t.color = 'amarilla'), 0)                      AS amarillas,
         COALESCE(SUM(t.color = 'roja'), 0)                          AS rojas,
         COALESCE(SUM(t.color = 'amarilla'), 0)
           + 3 * COALESCE(SUM(t.color = 'roja'), 0)                  AS puntos_fair_play
  FROM equipo e
  LEFT JOIN planilla_partido pp ON pp.id_equipo = e.id_equipo
  LEFT JOIN tarjeta t ON t.id_partido = pp.id_partido AND t.ci_jugador = pp.ci_jugador
  GROUP BY e.id_torneo, e.id_equipo, e.nombre
) f;


-- Vista del promedio de goles por partido: por fecha y por edición

CREATE OR REPLACE VIEW v_promedio_goles_por_fecha AS
SELECT id_torneo, numero_fecha,
       COUNT(*)                                       AS partidos_jugados,
       SUM(goles_local + goles_visitante)             AS goles_totales,
       ROUND(AVG(goles_local + goles_visitante), 2)   AS promedio_goles
FROM v_resultado_partido
GROUP BY id_torneo, numero_fecha;

CREATE OR REPLACE VIEW v_promedio_goles_por_edicion AS
SELECT id_torneo,
       COUNT(*)                                       AS partidos_jugados,
       SUM(goles_local + goles_visitante)             AS goles_totales,
       ROUND(AVG(goles_local + goles_visitante), 2)   AS promedio_goles
FROM v_resultado_partido
GROUP BY id_torneo;


-- Vista de las canchas y los turnos más utilizados (partidos jugados)

CREATE OR REPLACE VIEW v_uso_canchas AS
SELECT p.id_torneo, c.nombre AS complejo, p.nombre_cancha,
       COUNT(*) AS partidos,
       RANK() OVER (PARTITION BY p.id_torneo ORDER BY COUNT(*) DESC) AS ranking
FROM partido p
JOIN complejo c ON c.id_complejo = p.id_complejo
WHERE p.estado = 'jugado'
GROUP BY p.id_torneo, c.nombre, p.id_complejo, p.nombre_cancha;

CREATE OR REPLACE VIEW v_uso_turnos AS
SELECT p.id_torneo, t.id_turno, t.hora_inicio, t.hora_fin,
       COUNT(*) AS partidos,
       RANK() OVER (PARTITION BY p.id_torneo ORDER BY COUNT(*) DESC) AS ranking
FROM partido p
JOIN turno t ON t.id_turno = p.id_turno
WHERE p.estado = 'jugado'
GROUP BY p.id_torneo, t.id_turno, t.hora_inicio, t.hora_fin;


-- Vista de los jugadores por facultad y por tipo 

CREATE OR REPLACE VIEW v_jugadores_por_facultad_tipo AS
SELECT f.id_facultad, f.nombre AS facultad, ti.tipo,
       COUNT(j.ci) AS cantidad
FROM facultad f
CROSS JOIN (SELECT 'grado' AS tipo UNION ALL SELECT 'posgrado'
            UNION ALL SELECT 'docente' UNION ALL SELECT 'funcionario') ti
LEFT JOIN jugador j ON j.id_facultad = f.id_facultad AND j.tipo = ti.tipo
GROUP BY f.id_facultad, f.nombre, ti.tipo;


-- Vista de inscriptos en un plantel que nunca figuraron en una planilla

CREATE OR REPLACE VIEW v_jugadores_sin_planilla AS
SELECT ejt.id_torneo, e.nombre AS equipo, j.ci, j.nombre, j.apellido, ejt.numero_camiseta
FROM equipo_jugador_torneo ejt
JOIN equipo e  ON e.id_equipo = ejt.id_equipo
JOIN jugador j ON j.ci = ejt.ci_jugador
WHERE NOT EXISTS (SELECT 1
                    FROM planilla_partido pp
                    JOIN partido p ON p.id_partido = pp.id_partido
                   WHERE pp.ci_jugador = ejt.ci_jugador
                     AND p.id_torneo = ejt.id_torneo);


-- Vista de la cantidad de sanciones por equipo y por motivo

CREATE OR REPLACE VIEW v_sanciones_por_equipo_motivo AS
SELECT s.id_torneo, e.id_equipo, e.nombre AS equipo, s.motivo,
       COUNT(*) AS cantidad_sanciones
FROM sancion_jugador s
JOIN equipo_jugador_torneo ejt
     ON ejt.ci_jugador = s.ci_jugador AND ejt.id_torneo = s.id_torneo
JOIN equipo e ON e.id_equipo = ejt.id_equipo
GROUP BY s.id_torneo, e.id_equipo, e.nombre, s.motivo;


-- Vista del porcentaje de partidos jugados vs. postergados/cancelados

CREATE OR REPLACE VIEW v_porcentaje_partidos AS
SELECT id_torneo,
       COUNT(*)                                   AS total_partidos,
       SUM(estado = 'jugado')                     AS jugados,
       SUM(estado = 'postergado')                 AS postergados,
       SUM(estado = 'cancelado')                  AS cancelados,
       SUM(estado = 'programado')                 AS programados,
       ROUND(100 * SUM(estado = 'jugado')     / COUNT(*), 2) AS pct_jugados,
       ROUND(100 * SUM(estado = 'postergado') / COUNT(*), 2) AS pct_postergados,
       ROUND(100 * SUM(estado = 'cancelado')  / COUNT(*), 2) AS pct_cancelados
FROM partido
GROUP BY id_torneo;


-- Vista de jugadores suspendidos en cada fecha

CREATE OR REPLACE VIEW v_suspendidos_por_fecha AS
SELECT s.id_torneo, ft.numero_fecha, j.ci, j.nombre, j.apellido,
       e.nombre AS equipo, s.motivo
FROM sancion_jugador s
JOIN fecha_torneo ft
     ON ft.id_torneo = s.id_torneo
    AND ft.numero_fecha BETWEEN s.numero_fecha_inicio
                            AND s.numero_fecha_inicio + s.cantidad_fechas - 1
JOIN jugador j ON j.ci = s.ci_jugador
LEFT JOIN equipo_jugador_torneo ejt
       ON ejt.ci_jugador = s.ci_jugador AND ejt.id_torneo = s.id_torneo
LEFT JOIN equipo e ON e.id_equipo = ejt.id_equipo;

--  Vista de la valla menos vencida: goles en contra y partidos con el arco en cero
CREATE OR REPLACE VIEW v_valla_menos_vencida AS
SELECT RANK() OVER (PARTITION BY v.id_torneo ORDER BY v.goles_contra ASC) AS posicion, v.*
FROM (
  SELECT e.id_torneo, e.id_equipo, e.nombre AS equipo,
         COUNT(ep.id_partido)                  AS partidos_jugados,
         COALESCE(SUM(ep.gc), 0)               AS goles_contra,
         COALESCE(SUM(ep.gc = 0), 0)           AS partidos_arco_en_cero
  FROM equipo e
  LEFT JOIN v_equipo_partido ep
         ON ep.id_equipo = e.id_equipo AND ep.id_torneo = e.id_torneo
  GROUP BY e.id_torneo, e.id_equipo, e.nombre
) v;

-- Vista del control disciplinario por jugador: amarillas acumuladas y cuántas faltan
--     para la próxima suspensión automática (cada 3)

CREATE OR REPLACE VIEW v_disciplina_jugador AS
SELECT p.id_torneo, j.ci, j.nombre, j.apellido, e.nombre AS equipo,
       SUM(t.color = 'amarilla') AS amarillas,
       SUM(t.color = 'roja')     AS rojas,
       3 - (SUM(t.color = 'amarilla') % 3) AS amarillas_para_suspension
FROM tarjeta t
JOIN partido p ON p.id_partido = t.id_partido
JOIN jugador j ON j.ci = t.ci_jugador
JOIN equipo_jugador_torneo ejt
     ON ejt.ci_jugador = t.ci_jugador AND ejt.id_torneo = p.id_torneo
JOIN equipo e ON e.id_equipo = ejt.id_equipo
GROUP BY p.id_torneo, j.ci, j.nombre, j.apellido, e.nombre;
