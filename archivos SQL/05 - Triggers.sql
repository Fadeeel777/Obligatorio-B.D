
USE torneo_futbol5;

DELIMITER $$



-- Trigger en caso de que el jugador esté suspendido

DROP FUNCTION IF EXISTS fn_sancionado$$
CREATE FUNCTION fn_sancionado(p_ci VARCHAR(8), p_id_torneo INT, p_numero_fecha INT)
RETURNS TINYINT(1)
READS SQL DATA
BEGIN
  RETURN (SELECT COUNT(*) > 0
            FROM sancion_jugador s
           WHERE s.ci_jugador = p_ci
             AND s.id_torneo  = p_id_torneo
             AND p_numero_fecha BETWEEN s.numero_fecha_inicio
                                    AND s.numero_fecha_inicio + s.cantidad_fechas - 1);
END$$

-- Trigger para que la Planilla, goles y tarjetas solo se toquen con el partido jugado y dentro de
-- las 48 h posteriores a su disputa (fecha_hora_jugado).
DROP PROCEDURE IF EXISTS sp_exigir_partido_editable$$
CREATE PROCEDURE sp_exigir_partido_editable(IN p_id_partido INT)
BEGIN
  DECLARE v_estado VARCHAR(20) DEFAULT NULL;
  DECLARE v_fh DATETIME DEFAULT NULL;

  SELECT estado, fecha_hora_jugado INTO v_estado, v_fh
    FROM partido WHERE id_partido = p_id_partido;

  IF v_estado IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El partido no existe';
  END IF;
  IF v_estado <> 'jugado' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La planilla, los goles y las tarjetas solo se cargan una vez que el partido fue marcado como jugado';
  END IF;
  IF NOW() > v_fh + INTERVAL 48 HOUR THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Pasaron mas de 48 horas desde que se disputo el partido: ya no se puede modificar';
  END IF;
END$$

-- Trigger para que un partido solo puede marcarse como jugado si su día y turno ya pasaron.
DROP PROCEDURE IF EXISTS sp_exigir_turno_pasado$$
CREATE PROCEDURE sp_exigir_turno_pasado(IN p_dia DATE, IN p_id_turno INT)
BEGIN
  DECLARE v_fin TIME DEFAULT NULL;
  SELECT hora_fin INTO v_fin FROM turno WHERE id_turno = p_id_turno;
  IF v_fin IS NULL OR TIMESTAMP(p_dia, v_fin) > NOW() THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El partido solo puede marcarse como jugado cuando su dia y turno ya pasaron';
  END IF;
END$$

-- Trigger con reglas al programar un partido (p_id_partido = 0 si todavía no existe).
DROP PROCEDURE IF EXISTS sp_validar_partido$$
CREATE PROCEDURE sp_validar_partido(
  IN p_id_partido INT, IN p_id_torneo INT, IN p_numero_fecha INT,
  IN p_local INT, IN p_visitante INT, IN p_dia DATE, IN p_id_turno INT,
  IN p_cancha VARCHAR(50), IN p_id_complejo INT)
BEGIN
  DECLARE v_estado_torneo VARCHAR(20) DEFAULT NULL;
  DECLARE v_desde DATE DEFAULT NULL;
  DECLARE v_hasta DATE DEFAULT NULL;

  SELECT estado INTO v_estado_torneo FROM torneo WHERE id_torneo = p_id_torneo;
  IF v_estado_torneo = 'finalizado' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El torneo esta finalizado: no se pueden programar partidos';
  END IF;

  -- Trigger para que el día caiga dentro de la fecha del torneo
  SELECT fecha_desde, fecha_hasta INTO v_desde, v_hasta
    FROM fecha_torneo WHERE id_torneo = p_id_torneo AND numero_fecha = p_numero_fecha;
  IF p_dia < v_desde OR p_dia > v_hasta THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El dia del partido esta fuera del rango de la fecha del torneo';
  END IF;

  -- Trigger para que ambos equipos tengan al menos 5 jugadores en el plantel
  IF (SELECT COUNT(*) FROM equipo_jugador_torneo WHERE id_equipo = p_local) < 5
  OR (SELECT COUNT(*) FROM equipo_jugador_torneo WHERE id_equipo = p_visitante) < 5 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Ambos equipos deben tener al menos 5 jugadores en su plantel';
  END IF;

  -- Trigger para que no se pueda repetir un rival en la edición (salvo partido cancelado)
  IF EXISTS (SELECT 1 FROM partido x
              WHERE x.id_torneo = p_id_torneo AND x.id_partido <> p_id_partido
                AND x.estado <> 'cancelado'
                AND ((x.id_equipo_local = p_local     AND x.id_equipo_visitante = p_visitante)
                  OR (x.id_equipo_local = p_visitante AND x.id_equipo_visitante = p_local))) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Estos equipos ya tienen un partido en esta edicion (salvo que haya sido cancelado)';
  END IF;

  -- Trigger para que un equipo no juegue más de un partido por fecha
  IF EXISTS (SELECT 1 FROM partido x
              WHERE x.id_torneo = p_id_torneo AND x.numero_fecha = p_numero_fecha
                AND x.id_partido <> p_id_partido AND x.estado <> 'cancelado'
                AND (x.id_equipo_local     IN (p_local, p_visitante)
                  OR x.id_equipo_visitante IN (p_local, p_visitante))) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Uno de los equipos ya juega otro partido en esa fecha del torneo';
  END IF;

  -- Trigger de que la cancha esté libre en ese día y turno
  IF EXISTS (SELECT 1 FROM partido x
              WHERE x.id_partido <> p_id_partido AND x.estado <> 'cancelado'
                AND x.id_complejo = p_id_complejo AND x.nombre_cancha = p_cancha
                AND x.dia = p_dia AND x.id_turno = p_id_turno) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La cancha ya tiene un partido asignado en ese dia y turno';
  END IF;
END$$


-- Trigger de login: la contraseña debe ser un hash bcrypt (nunca texto plano)

DROP TRIGGER IF EXISTS trg_login_bi$$
CREATE TRIGGER trg_login_bi BEFORE INSERT ON login FOR EACH ROW
BEGIN
  IF NEW.contrasena NOT REGEXP '^\\$2[aby]\\$[0-9]{2}\\$.{53}$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La contrasena debe guardarse como hash bcrypt';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_login_bu$$
CREATE TRIGGER trg_login_bu BEFORE UPDATE ON login FOR EACH ROW
BEGIN
  IF NEW.contrasena NOT REGEXP '^\\$2[aby]\\$[0-9]{2}\\$.{53}$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La contrasena debe guardarse como hash bcrypt';
  END IF;
END$$


-- Trigger de jugador: no se debe cambiar facultad/tipo mientras integra un plantel

DROP TRIGGER IF EXISTS trg_jugador_bu$$
CREATE TRIGGER trg_jugador_bu BEFORE UPDATE ON jugador FOR EACH ROW
BEGIN
  IF (NEW.id_facultad <> OLD.id_facultad OR NEW.tipo <> OLD.tipo)
     AND EXISTS (SELECT 1 FROM equipo_jugador_torneo WHERE ci_jugador = OLD.ci) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'No se puede cambiar facultad o tipo de un jugador que integra un plantel';
  END IF;
END$$


-- Trigger del torneo: etapas inscripcion -> en_curso -> finalizado

DROP TRIGGER IF EXISTS trg_torneo_bi$$
CREATE TRIGGER trg_torneo_bi BEFORE INSERT ON torneo FOR EACH ROW
BEGIN
  IF NEW.estado <> 'inscripcion' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un torneo nuevo debe comenzar en etapa de inscripcion';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_torneo_bu$$
CREATE TRIGGER trg_torneo_bu BEFORE UPDATE ON torneo FOR EACH ROW
BEGIN
  IF NEW.estado <> OLD.estado THEN
    IF NOT ((OLD.estado = 'inscripcion' AND NEW.estado = 'en_curso')
         OR (OLD.estado = 'en_curso'    AND NEW.estado = 'finalizado')) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transicion de estado invalida (inscripcion -> en_curso -> finalizado)';
    END IF;

    IF NEW.estado = 'en_curso' THEN
      IF (SELECT COUNT(*) FROM equipo WHERE id_torneo = OLD.id_torneo) < 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Se necesitan al menos 2 equipos para iniciar el torneo';
      END IF;
      IF EXISTS (SELECT 1 FROM equipo e
                  WHERE e.id_torneo = OLD.id_torneo
                    AND (SELECT COUNT(*) FROM equipo_jugador_torneo j
                          WHERE j.id_equipo = e.id_equipo) NOT BETWEEN 5 AND 10) THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'Todos los planteles deben tener entre 5 y 10 jugadores para iniciar el torneo';
      END IF;
      IF EXISTS (SELECT 1 FROM equipo e
                  WHERE e.id_torneo = OLD.id_torneo
                    AND (e.ci_capitan IS NULL
                         OR NOT EXISTS (SELECT 1 FROM equipo_jugador_torneo j
                                         WHERE j.id_equipo = e.id_equipo
                                           AND j.ci_jugador = e.ci_capitan))) THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'Todos los equipos deben tener un capitan que integre su plantel';
      END IF;
    END IF;

    IF NEW.estado = 'finalizado' THEN
      IF EXISTS (SELECT 1 FROM partido
                  WHERE id_torneo = OLD.id_torneo AND estado IN ('programado','postergado')) THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'Hay partidos programados o postergados: jugalos o cancelalos antes de finalizar';
      END IF;
    END IF;
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_torneo_bd$$
CREATE TRIGGER trg_torneo_bd BEFORE DELETE ON torneo FOR EACH ROW
BEGIN
  IF OLD.estado <> 'inscripcion' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se puede eliminar un torneo en etapa de inscripcion';
  END IF;
END$$


-- Trigger de la fecha del torneo

DROP TRIGGER IF EXISTS trg_fecha_torneo_bi$$
CREATE TRIGGER trg_fecha_torneo_bi BEFORE INSERT ON fecha_torneo FOR EACH ROW
BEGIN
  DECLARE v_ini DATE; DECLARE v_fin DATE;
  SELECT fecha_inicio, fecha_fin INTO v_ini, v_fin FROM torneo WHERE id_torneo = NEW.id_torneo;
  IF NEW.fecha_desde < v_ini OR NEW.fecha_hasta > v_fin THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha debe estar dentro del periodo del torneo';
  END IF;
  IF EXISTS (SELECT 1 FROM fecha_torneo f
              WHERE f.id_torneo = NEW.id_torneo
                AND NEW.fecha_desde <= f.fecha_hasta AND NEW.fecha_hasta >= f.fecha_desde) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha se superpone con otra fecha del mismo torneo';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_fecha_torneo_bu$$
CREATE TRIGGER trg_fecha_torneo_bu BEFORE UPDATE ON fecha_torneo FOR EACH ROW
BEGIN
  DECLARE v_ini DATE; DECLARE v_fin DATE;
  SELECT fecha_inicio, fecha_fin INTO v_ini, v_fin FROM torneo WHERE id_torneo = NEW.id_torneo;
  IF NEW.fecha_desde < v_ini OR NEW.fecha_hasta > v_fin THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha debe estar dentro del periodo del torneo';
  END IF;
  IF EXISTS (SELECT 1 FROM fecha_torneo f
              WHERE f.id_torneo = NEW.id_torneo AND f.numero_fecha <> OLD.numero_fecha
                AND NEW.fecha_desde <= f.fecha_hasta AND NEW.fecha_hasta >= f.fecha_desde) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha se superpone con otra fecha del mismo torneo';
  END IF;
  IF EXISTS (SELECT 1 FROM partido p
              WHERE p.id_torneo = OLD.id_torneo AND p.numero_fecha = OLD.numero_fecha
                AND (p.dia < NEW.fecha_desde OR p.dia > NEW.fecha_hasta)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hay partidos de esta fecha que quedarian fuera del nuevo rango';
  END IF;
END$$


-- Trigger de equipo

DROP TRIGGER IF EXISTS trg_equipo_bi$$
CREATE TRIGGER trg_equipo_bi BEFORE INSERT ON equipo FOR EACH ROW
BEGIN
  IF (SELECT estado FROM torneo WHERE id_torneo = NEW.id_torneo) <> 'inscripcion' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Los equipos solo pueden inscribirse mientras el torneo esta en inscripcion';
  END IF;
  IF NEW.ci_capitan IS NOT NULL
     AND (SELECT id_facultad FROM jugador WHERE ci = NEW.ci_capitan) <> NEW.id_facultad THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El capitan debe pertenecer a la facultad del equipo';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_equipo_bu$$
CREATE TRIGGER trg_equipo_bu BEFORE UPDATE ON equipo FOR EACH ROW
BEGIN
  IF NEW.id_torneo <> OLD.id_torneo OR NEW.id_facultad <> OLD.id_facultad THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede cambiar el torneo ni la facultad de un equipo';
  END IF;
  IF (SELECT estado FROM torneo WHERE id_torneo = OLD.id_torneo) <> 'inscripcion' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Los equipos solo pueden modificarse mientras el torneo esta en inscripcion';
  END IF;
  IF NEW.ci_capitan IS NOT NULL AND NOT (NEW.ci_capitan <=> OLD.ci_capitan)
     AND NOT EXISTS (SELECT 1 FROM equipo_jugador_torneo
                      WHERE id_equipo = OLD.id_equipo AND ci_jugador = NEW.ci_capitan) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El capitan debe ser un jugador del plantel del equipo';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_equipo_bd$$
CREATE TRIGGER trg_equipo_bd BEFORE DELETE ON equipo FOR EACH ROW
BEGIN
  IF (SELECT estado FROM torneo WHERE id_torneo = OLD.id_torneo) <> 'inscripcion' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Los equipos solo pueden eliminarse mientras el torneo esta en inscripcion';
  END IF;
END$$


-- Trigger del plantel (equipo_jugador_torneo): 5-10 jugadores, misma facultad,
-- máximo 2 docentes/funcionarios, solo en etapa de inscripción
-- (el mínimo de 5 se exige al pasar el torneo a en_curso y al programar partidos)

DROP TRIGGER IF EXISTS trg_plantel_bi$$
CREATE TRIGGER trg_plantel_bi BEFORE INSERT ON equipo_jugador_torneo FOR EACH ROW
BEGIN
  DECLARE v_fac_equipo INT; DECLARE v_fac_jug INT; DECLARE v_tipo VARCHAR(20);

  IF (SELECT estado FROM torneo WHERE id_torneo = NEW.id_torneo) <> 'inscripcion' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Los planteles solo pueden modificarse mientras el torneo esta en inscripcion';
  END IF;

  SELECT id_facultad INTO v_fac_equipo FROM equipo WHERE id_equipo = NEW.id_equipo;
  SELECT id_facultad, tipo INTO v_fac_jug, v_tipo FROM jugador WHERE ci = NEW.ci_jugador;
  IF v_fac_equipo <> v_fac_jug THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El jugador debe pertenecer a la facultad que representa el equipo';
  END IF;

  IF (SELECT COUNT(*) FROM equipo_jugador_torneo WHERE id_equipo = NEW.id_equipo) >= 10 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El plantel ya tiene el maximo de 10 jugadores';
  END IF;

  IF v_tipo IN ('docente','funcionario')
     AND (SELECT COUNT(*) FROM equipo_jugador_torneo ejt
            JOIN jugador j ON j.ci = ejt.ci_jugador
           WHERE ejt.id_equipo = NEW.id_equipo
             AND j.tipo IN ('docente','funcionario')) >= 2 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cada plantel admite como maximo 2 jugadores docentes o funcionarios';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_plantel_bu$$
CREATE TRIGGER trg_plantel_bu BEFORE UPDATE ON equipo_jugador_torneo FOR EACH ROW
BEGIN
  IF NEW.id_equipo <> OLD.id_equipo OR NEW.ci_jugador <> OLD.ci_jugador OR NEW.id_torneo <> OLD.id_torneo THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Para cambiar de equipo o jugador, eliminá la fila y volvé a agregarla';
  END IF;
  IF (SELECT estado FROM torneo WHERE id_torneo = OLD.id_torneo) <> 'inscripcion' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Los planteles solo pueden modificarse mientras el torneo esta en inscripcion';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_plantel_bd$$
CREATE TRIGGER trg_plantel_bd BEFORE DELETE ON equipo_jugador_torneo FOR EACH ROW
BEGIN
  IF (SELECT estado FROM torneo WHERE id_torneo = OLD.id_torneo) <> 'inscripcion' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Los planteles solo pueden modificarse mientras el torneo esta en inscripcion';
  END IF;
  IF EXISTS (SELECT 1 FROM equipo WHERE id_equipo = OLD.id_equipo AND ci_capitan = OLD.ci_jugador) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede sacar del plantel al capitan: cambia el capitan primero';
  END IF;
END$$


-- Trigger de partido

DROP TRIGGER IF EXISTS trg_partido_bi$$
CREATE TRIGGER trg_partido_bi BEFORE INSERT ON partido FOR EACH ROW
BEGIN
  IF NEW.estado <> 'cancelado' THEN
    CALL sp_validar_partido(0, NEW.id_torneo, NEW.numero_fecha, NEW.id_equipo_local,
                            NEW.id_equipo_visitante, NEW.dia, NEW.id_turno,
                            NEW.nombre_cancha, NEW.id_complejo);
  END IF;
  IF NEW.estado = 'jugado' THEN
    CALL sp_exigir_turno_pasado(NEW.dia, NEW.id_turno);
    IF NEW.fecha_hora_jugado IS NULL THEN SET NEW.fecha_hora_jugado = NOW(); END IF;
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_partido_bu$$
CREATE TRIGGER trg_partido_bu BEFORE UPDATE ON partido FOR EACH ROW
BEGIN
  IF OLD.estado = 'jugado' THEN
    -- un partido jugado queda congelado; el resultado se corrige con goles (48 h)
    IF NOT (NEW.estado = OLD.estado
            AND NEW.id_torneo = OLD.id_torneo AND NEW.numero_fecha = OLD.numero_fecha
            AND NEW.id_equipo_local = OLD.id_equipo_local
            AND NEW.id_equipo_visitante = OLD.id_equipo_visitante
            AND NEW.dia = OLD.dia AND NEW.id_turno = OLD.id_turno
            AND NEW.nombre_cancha = OLD.nombre_cancha AND NEW.id_complejo = OLD.id_complejo
            AND NEW.fecha_hora_jugado <=> OLD.fecha_hora_jugado) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Un partido jugado no puede modificarse; su resultado se corrige via goles dentro de las 48 horas';
    END IF;
  ELSE
    IF NEW.estado = 'jugado' THEN
      IF OLD.estado NOT IN ('programado','postergado') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo un partido programado o postergado puede marcarse como jugado';
      END IF;
      CALL sp_exigir_turno_pasado(NEW.dia, NEW.id_turno);
      IF NEW.fecha_hora_jugado IS NULL THEN SET NEW.fecha_hora_jugado = NOW(); END IF;
    END IF;
    IF NEW.estado <> 'cancelado' THEN
      CALL sp_validar_partido(OLD.id_partido, NEW.id_torneo, NEW.numero_fecha,
                              NEW.id_equipo_local, NEW.id_equipo_visitante, NEW.dia,
                              NEW.id_turno, NEW.nombre_cancha, NEW.id_complejo);
    END IF;
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_partido_bd$$
CREATE TRIGGER trg_partido_bd BEFORE DELETE ON partido FOR EACH ROW
BEGIN
  IF OLD.estado = 'jugado' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un partido jugado no puede eliminarse';
  END IF;
END$$


-- Trigger de planilla

DROP TRIGGER IF EXISTS trg_planilla_bi$$
CREATE TRIGGER trg_planilla_bi BEFORE INSERT ON planilla_partido FOR EACH ROW
BEGIN
  DECLARE v_torneo INT; DECLARE v_fecha INT; DECLARE v_local INT; DECLARE v_vis INT;

  CALL sp_exigir_partido_editable(NEW.id_partido);

  SELECT id_torneo, numero_fecha, id_equipo_local, id_equipo_visitante
    INTO v_torneo, v_fecha, v_local, v_vis
    FROM partido WHERE id_partido = NEW.id_partido;

  IF NEW.id_equipo NOT IN (v_local, v_vis) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El jugador debe ser del plantel de alguno de los dos equipos del partido';
  END IF;
  IF fn_sancionado(NEW.ci_jugador, v_torneo, v_fecha) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El jugador esta suspendido en esta fecha y no puede figurar en la planilla';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_planilla_bu$$
CREATE TRIGGER trg_planilla_bu BEFORE UPDATE ON planilla_partido FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'La planilla no se modifica: elimina la fila y vuelve a agregar al jugador';
END$$

DROP TRIGGER IF EXISTS trg_planilla_bd$$
CREATE TRIGGER trg_planilla_bd BEFORE DELETE ON planilla_partido FOR EACH ROW
BEGIN
  CALL sp_exigir_partido_editable(OLD.id_partido);
  IF EXISTS (SELECT 1 FROM gol     WHERE id_partido = OLD.id_partido AND ci_jugador = OLD.ci_jugador)
  OR EXISTS (SELECT 1 FROM tarjeta WHERE id_partido = OLD.id_partido AND ci_jugador = OLD.ci_jugador) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Primero elimina los goles y tarjetas de ese jugador en el partido';
  END IF;
END$$


-- Triggeer de goles

DROP TRIGGER IF EXISTS trg_gol_bi$$
CREATE TRIGGER trg_gol_bi BEFORE INSERT ON gol FOR EACH ROW
BEGIN
  CALL sp_exigir_partido_editable(NEW.id_partido);
  IF NOT EXISTS (SELECT 1 FROM planilla_partido
                  WHERE id_partido = NEW.id_partido AND ci_jugador = NEW.ci_jugador) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo pueden convertir goles los jugadores que figuran en la planilla';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_gol_bu$$
CREATE TRIGGER trg_gol_bu BEFORE UPDATE ON gol FOR EACH ROW
BEGIN
  CALL sp_exigir_partido_editable(OLD.id_partido);
  CALL sp_exigir_partido_editable(NEW.id_partido);
  IF NOT EXISTS (SELECT 1 FROM planilla_partido
                  WHERE id_partido = NEW.id_partido AND ci_jugador = NEW.ci_jugador) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo pueden convertir goles los jugadores que figuran en la planilla';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_gol_bd$$
CREATE TRIGGER trg_gol_bd BEFORE DELETE ON gol FOR EACH ROW
BEGIN
  CALL sp_exigir_partido_editable(OLD.id_partido);
END$$


-- Trigger de tarjetas

DROP TRIGGER IF EXISTS trg_tarjeta_bi$$
CREATE TRIGGER trg_tarjeta_bi BEFORE INSERT ON tarjeta FOR EACH ROW
BEGIN
  CALL sp_exigir_partido_editable(NEW.id_partido);
  IF NOT EXISTS (SELECT 1 FROM planilla_partido
                  WHERE id_partido = NEW.id_partido AND ci_jugador = NEW.ci_jugador) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo pueden recibir tarjetas los jugadores que figuran en la planilla';
  END IF;
  IF EXISTS (SELECT 1 FROM tarjeta WHERE id_partido = NEW.id_partido
                AND ci_jugador = NEW.ci_jugador AND color = 'roja') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El jugador ya fue expulsado en este partido';
  END IF;
  IF NEW.color = 'amarilla'
     AND (SELECT COUNT(*) FROM tarjeta WHERE id_partido = NEW.id_partido
             AND ci_jugador = NEW.ci_jugador AND color = 'amarilla') >= 2 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El jugador ya tiene 2 amarillas en este partido: corresponde registrar una roja';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_tarjeta_ai$$
CREATE TRIGGER trg_tarjeta_ai AFTER INSERT ON tarjeta FOR EACH ROW
BEGIN
  DECLARE v_torneo INT; DECLARE v_fecha INT; DECLARE v_n INT;

  SELECT id_torneo, numero_fecha INTO v_torneo, v_fecha
    FROM partido WHERE id_partido = NEW.id_partido;

  IF NEW.color = 'roja' THEN
    INSERT INTO sancion_jugador (ci_jugador, id_torneo, motivo, numero_fecha_inicio, cantidad_fechas, id_tarjeta_origen)
    VALUES (NEW.ci_jugador, v_torneo, 'roja', v_fecha + 1, 1, NEW.id_tarjeta);
  ELSE
    SELECT COUNT(*) INTO v_n
      FROM tarjeta t JOIN partido p ON p.id_partido = t.id_partido
     WHERE t.ci_jugador = NEW.ci_jugador AND p.id_torneo = v_torneo AND t.color = 'amarilla';
    IF v_n % 3 = 0 THEN
      INSERT INTO sancion_jugador (ci_jugador, id_torneo, motivo, numero_fecha_inicio, cantidad_fechas, id_tarjeta_origen)
      VALUES (NEW.ci_jugador, v_torneo, 'acumulacion_amarillas', v_fecha + 1, 1, NEW.id_tarjeta);
    END IF;
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_tarjeta_bu$$
CREATE TRIGGER trg_tarjeta_bu BEFORE UPDATE ON tarjeta FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Las tarjetas no se modifican: eliminala y volve a registrarla';
END$$

DROP TRIGGER IF EXISTS trg_tarjeta_bd$$
CREATE TRIGGER trg_tarjeta_bd BEFORE DELETE ON tarjeta FOR EACH ROW
BEGIN
  CALL sp_exigir_partido_editable(OLD.id_partido);
  
  DELETE FROM sancion_jugador WHERE id_tarjeta_origen = OLD.id_tarjeta;
END$$


-- Trigger de sanciones

DROP TRIGGER IF EXISTS trg_sancion_bi$$
CREATE TRIGGER trg_sancion_bi BEFORE INSERT ON sancion_jugador FOR EACH ROW
BEGIN
  DECLARE v_color VARCHAR(10); DECLARE v_ci VARCHAR(8);

  IF NOT EXISTS (SELECT 1 FROM equipo_jugador_torneo
                  WHERE ci_jugador = NEW.ci_jugador AND id_torneo = NEW.id_torneo) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El jugador no integra ningun plantel de ese torneo';
  END IF;

  IF NEW.motivo = 'disciplinaria' THEN
    IF NEW.id_tarjeta_origen IS NOT NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una sancion disciplinaria no tiene tarjeta de origen';
    END IF;
  ELSE
    IF NEW.id_tarjeta_origen IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Las sanciones por roja o amarillas requieren la tarjeta de origen';
    END IF;
    IF NEW.cantidad_fechas <> 1 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Las sanciones por tarjeta son de una fecha';
    END IF;
    SELECT color, ci_jugador INTO v_color, v_ci FROM tarjeta WHERE id_tarjeta = NEW.id_tarjeta_origen;
    IF v_ci <> NEW.ci_jugador
       OR (NEW.motivo = 'roja' AND v_color <> 'roja')
       OR (NEW.motivo = 'acumulacion_amarillas' AND v_color <> 'amarilla') THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La tarjeta de origen no coincide con el jugador o el motivo';
    END IF;
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_sancion_bu$$
CREATE TRIGGER trg_sancion_bu BEFORE UPDATE ON sancion_jugador FOR EACH ROW
BEGIN
  IF OLD.motivo <> 'disciplinaria' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Las sanciones automaticas no se editan; se eliminan junto con su tarjeta';
  END IF;
  IF NEW.motivo <> 'disciplinaria' OR NEW.id_tarjeta_origen IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una sancion disciplinaria no puede convertirse en automatica';
  END IF;
  IF NEW.ci_jugador <> OLD.ci_jugador OR NEW.id_torneo <> OLD.id_torneo THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede cambiar el jugador ni el torneo de una sancion';
  END IF;
END$$

DELIMITER ;
