package com.banca.dao;

import com.banca.model.Cuenta;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.math.BigDecimal;
import java.sql.*;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

/**
 * DAO de Cuenta - compatible con MySQL 5.7
 */
public class CuentaDAO {

    private static final Logger logger = LogManager.getLogger(CuentaDAO.class);

    private static final String SELECT_BASE =
        "SELECT c.id, c.numero_cuenta, c.tipo_cuenta, c.moneda, " +
        "c.saldo, c.saldo_disponible, c.estado, c.usuario_id, " +
        "c.fecha_apertura, c.cci, u.nombres, u.apellidos " +
        "FROM cuenta c INNER JOIN usuario u ON c.usuario_id = u.id ";

    public List<Cuenta> findByUsuario(Connection conn, Long usuarioId) throws SQLException {
        String sql = SELECT_BASE +
                     "WHERE c.usuario_id = ? AND c.estado = 'ACTIVA' " +
                     "ORDER BY c.tipo_cuenta, c.moneda";
        List<Cuenta> lista = new ArrayList<Cuenta>();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, usuarioId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) lista.add(map(rs));
            }
        }
        return lista;
    }

    public List<Cuenta> findByUsuarioAndTipo(Connection conn, Long usuarioId, String tipoCuenta) throws SQLException {
        String sql = SELECT_BASE +
                     "WHERE c.usuario_id = ? AND c.estado = 'ACTIVA' AND c.tipo_cuenta = ? " +
                     "ORDER BY c.moneda";
        List<Cuenta> lista = new ArrayList<Cuenta>();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, usuarioId);
            ps.setString(2, tipoCuenta);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) lista.add(map(rs));
            }
        }
        return lista;
    }

    public Cuenta findById(Connection conn, Long id) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement(SELECT_BASE + "WHERE c.id = ?")) {
            ps.setLong(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return map(rs);
            }
        }
        return null;
    }

    public Cuenta findByNumeroCuenta(Connection conn, String numeroCuenta) throws SQLException {
        String sql = SELECT_BASE + "WHERE c.numero_cuenta = ? AND c.estado = 'ACTIVA'";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, numeroCuenta);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return map(rs);
            }
        }
        return null;
    }

    public void actualizarSaldo(Connection conn, Long id,
                                BigDecimal saldo, BigDecimal saldoDisponible) throws SQLException {
        String sql = "UPDATE cuenta SET saldo = ?, saldo_disponible = ? WHERE id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setBigDecimal(1, saldo);
            ps.setBigDecimal(2, saldoDisponible);
            ps.setLong(3, id);
            ps.executeUpdate();
        }
    }

    private Cuenta map(ResultSet rs) throws SQLException {
        Cuenta c = new Cuenta();
        c.setId(rs.getLong("id"));
        c.setNumeroCuenta(rs.getString("numero_cuenta"));
        c.setTipoCuenta(rs.getString("tipo_cuenta"));
        c.setMoneda(rs.getString("moneda"));
        c.setSaldo(rs.getBigDecimal("saldo"));
        c.setSaldoDisponible(rs.getBigDecimal("saldo_disponible"));
        c.setEstado(rs.getString("estado"));
        c.setUsuarioId(rs.getLong("usuario_id"));
        c.setCci(rs.getString("cci"));
        c.setUsuarioNombre(rs.getString("nombres") + " " + rs.getString("apellidos"));
        Timestamp fa = rs.getTimestamp("fecha_apertura");
        if (fa != null) c.setFechaApertura(new Date(fa.getTime()));
        return c;
    }
}
