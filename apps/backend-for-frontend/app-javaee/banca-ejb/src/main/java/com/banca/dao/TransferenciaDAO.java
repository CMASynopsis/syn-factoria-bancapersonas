package com.banca.dao;

import com.banca.model.Transferencia;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.sql.*;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

/**
 * DAO de Transferencia - compatible con MySQL 5.7
 * IMPORTANTE: Usa LIMIT (MySQL) en lugar de FETCH FIRST (Oracle)
 */
public class TransferenciaDAO {

    private static final Logger logger = LogManager.getLogger(TransferenciaDAO.class);

    public Long insertar(Connection conn, Transferencia t) throws SQLException {
        String sql =
            "INSERT INTO transferencia " +
            "(numero_operacion, tipo_transferencia, cuenta_origen_id, cuenta_origen_numero, " +
            " cuenta_destino_id, cuenta_destino_numero, cuenta_destino_cci, banco_destino, " +
            " titular_destino, monto, moneda, glosa, estado, usuario_id, " +
            " fecha_operacion, fecha_valor) " +
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW(),NOW())";

        try (PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, t.getNumeroOperacion());
            ps.setString(2, t.getTipoTransferencia());
            ps.setLong(3, t.getCuentaOrigenId());
            ps.setString(4, t.getCuentaOrigenNumero());

            if (t.getCuentaDestinoId() != null) ps.setLong(5, t.getCuentaDestinoId());
            else ps.setNull(5, Types.BIGINT);

            ps.setString(6, t.getCuentaDestinoNumero());
            ps.setString(7, t.getCuentaDestinoCci());
            ps.setString(8, t.getBancoDestino());
            ps.setString(9, t.getTitularDestino());
            ps.setBigDecimal(10, t.getMonto());
            ps.setString(11, t.getMoneda());
            ps.setString(12, t.getGlosa());
            ps.setString(13, t.getEstado());
            ps.setLong(14, t.getUsuarioId());

            ps.executeUpdate();

            try (ResultSet keys = ps.getGeneratedKeys()) {
                if (keys.next()) {
                    Long id = keys.getLong(1);
                    t.setId(id);
                    return id;
                }
            }
        }
        return null;
    }

    // MySQL 5.7: usa LIMIT, no FETCH FIRST
    public List<Transferencia> findByUsuario(Connection conn, Long usuarioId) throws SQLException {
        String sql =
            "SELECT id, numero_operacion, tipo_transferencia, " +
            "cuenta_origen_id, cuenta_origen_numero, cuenta_destino_id, " +
            "cuenta_destino_numero, cuenta_destino_cci, banco_destino, " +
            "titular_destino, monto, moneda, glosa, estado, motivo_rechazo, " +
            "fecha_operacion, fecha_valor, usuario_id " +
            "FROM transferencia WHERE usuario_id = ? " +
            "ORDER BY fecha_operacion DESC LIMIT 20";

        List<Transferencia> lista = new ArrayList<Transferencia>();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, usuarioId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) lista.add(map(rs));
            }
        }
        return lista;
    }

    private Transferencia map(ResultSet rs) throws SQLException {
        Transferencia t = new Transferencia();
        t.setId(rs.getLong("id"));
        t.setNumeroOperacion(rs.getString("numero_operacion"));
        t.setTipoTransferencia(rs.getString("tipo_transferencia"));
        t.setCuentaOrigenId(rs.getLong("cuenta_origen_id"));
        t.setCuentaOrigenNumero(rs.getString("cuenta_origen_numero"));
        long cdi = rs.getLong("cuenta_destino_id");
        if (!rs.wasNull()) t.setCuentaDestinoId(cdi);
        t.setCuentaDestinoNumero(rs.getString("cuenta_destino_numero"));
        t.setCuentaDestinoCci(rs.getString("cuenta_destino_cci"));
        t.setBancoDestino(rs.getString("banco_destino"));
        t.setTitularDestino(rs.getString("titular_destino"));
        t.setMonto(rs.getBigDecimal("monto"));
        t.setMoneda(rs.getString("moneda"));
        t.setGlosa(rs.getString("glosa"));
        t.setEstado(rs.getString("estado"));
        t.setMotivoRechazo(rs.getString("motivo_rechazo"));
        t.setUsuarioId(rs.getLong("usuario_id"));
        Timestamp fo = rs.getTimestamp("fecha_operacion");
        if (fo != null) t.setFechaOperacion(new Date(fo.getTime()));
        Timestamp fv = rs.getTimestamp("fecha_valor");
        if (fv != null) t.setFechaValor(new Date(fv.getTime()));
        return t;
    }
}
