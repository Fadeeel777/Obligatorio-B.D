
USE torneo_futbol5;

DROP USER IF EXISTS 'login_app'@'%';
DROP USER IF EXISTS 'admin_app'@'%';
DROP USER IF EXISTS 'planillero_app'@'%';

CREATE USER 'login_app'@'%'      IDENTIFIED BY 'cambiar_clave_login';
CREATE USER 'admin_app'@'%'      IDENTIFIED BY 'cambiar_clave_admin';
CREATE USER 'planillero_app'@'%' IDENTIFIED BY 'cambiar_clave_planillero';

-- login_app: solo lee la tabla login
GRANT SELECT ON torneo_futbol5.login TO 'login_app'@'%';

--  admin_app: gestiona todo el torneo
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.facultad              TO 'admin_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.jugador               TO 'admin_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.complejo              TO 'admin_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.cancha                TO 'admin_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.turno                 TO 'admin_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.torneo                TO 'admin_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.fecha_torneo          TO 'admin_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.equipo                TO 'admin_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.equipo_jugador_torneo TO 'admin_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.partido               TO 'admin_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.planilla_partido      TO 'admin_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.gol                   TO 'admin_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.tarjeta               TO 'admin_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_futbol5.sancion_jugador       TO 'admin_app'@'%';
GRANT SELECT (correo, rol), INSERT, UPDATE, DELETE ON torneo_futbol5.login   TO 'admin_app'@'%';
GRANT EXECUTE ON torneo_futbol5.* TO 'admin_app'@'%';

-- planillero_app: lee (sin login) y puede ejecutar los procedimientos de planilla
GRANT SELECT ON torneo_futbol5.facultad              TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.jugador               TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.complejo              TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.cancha                TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.turno                 TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.torneo                TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.fecha_torneo          TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.equipo                TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.equipo_jugador_torneo TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.partido               TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.planilla_partido      TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.gol                   TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.tarjeta               TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.sancion_jugador       TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_partido_detalle     TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_resultado_partido   TO 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_suspendidos_por_fecha TO 'planillero_app'@'%';

GRANT EXECUTE ON PROCEDURE torneo_futbol5.sp_marcar_partido_jugado TO 'planillero_app'@'%';
GRANT EXECUTE ON PROCEDURE torneo_futbol5.sp_agregar_a_planilla    TO 'planillero_app'@'%';
GRANT EXECUTE ON PROCEDURE torneo_futbol5.sp_quitar_de_planilla    TO 'planillero_app'@'%';
GRANT EXECUTE ON PROCEDURE torneo_futbol5.sp_registrar_gol         TO 'planillero_app'@'%';
GRANT EXECUTE ON PROCEDURE torneo_futbol5.sp_eliminar_gol          TO 'planillero_app'@'%';
GRANT EXECUTE ON PROCEDURE torneo_futbol5.sp_registrar_tarjeta     TO 'planillero_app'@'%';
GRANT EXECUTE ON PROCEDURE torneo_futbol5.sp_eliminar_tarjeta      TO 'planillero_app'@'%';

-- Reportes (vistas): ambos roles pueden consultarlos
GRANT SELECT ON torneo_futbol5.v_tabla_posiciones           TO 'admin_app'@'%', 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_goleadores                 TO 'admin_app'@'%', 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_fair_play                  TO 'admin_app'@'%', 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_promedio_goles_por_fecha   TO 'admin_app'@'%', 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_promedio_goles_por_edicion TO 'admin_app'@'%', 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_uso_canchas                TO 'admin_app'@'%', 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_uso_turnos                 TO 'admin_app'@'%', 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_jugadores_por_facultad_tipo TO 'admin_app'@'%', 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_jugadores_sin_planilla     TO 'admin_app'@'%', 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_sanciones_por_equipo_motivo TO 'admin_app'@'%', 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_porcentaje_partidos        TO 'admin_app'@'%', 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_valla_menos_vencida        TO 'admin_app'@'%', 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_disciplina_jugador         TO 'admin_app'@'%', 'planillero_app'@'%';
GRANT SELECT ON torneo_futbol5.v_equipo_partido             TO 'admin_app'@'%';
GRANT SELECT ON torneo_futbol5.v_partido_detalle            TO 'admin_app'@'%';
GRANT SELECT ON torneo_futbol5.v_resultado_partido          TO 'admin_app'@'%';
GRANT SELECT ON torneo_futbol5.v_suspendidos_por_fecha      TO 'admin_app'@'%';

FLUSH PRIVILEGES;
