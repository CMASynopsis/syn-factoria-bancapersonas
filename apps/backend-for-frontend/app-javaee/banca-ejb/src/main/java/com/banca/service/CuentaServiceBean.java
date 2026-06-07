package com.banca.service;

import com.banca.dao.CuentaDAO;
import com.banca.model.Cuenta;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import javax.annotation.Resource;
import javax.ejb.Stateless;
import javax.ejb.TransactionAttribute;
import javax.ejb.TransactionAttributeType;
import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

@Stateless
@TransactionAttribute(TransactionAttributeType.SUPPORTS)
public class CuentaServiceBean implements CuentaServiceLocal {

    private static final Logger logger = LogManager.getLogger(CuentaServiceBean.class);

    @Resource(lookup = "java:jboss/datasources/BancaDS")
    private DataSource dataSource;

    @Override
    public List<Cuenta> obtenerCuentasUsuario(Long usuarioId) {
        try (Connection conn = dataSource.getConnection()) {
            return new CuentaDAO().findByUsuario(conn, usuarioId);
        } catch (SQLException e) {
            logger.error("Error obteniendo cuentas usuario {}", usuarioId, e);
            return new ArrayList<Cuenta>();
        }
    }

    @Override
    public List<Cuenta> obtenerCuentasUsuarioPorTipo(Long usuarioId, String tipoCuenta) {
        try (Connection conn = dataSource.getConnection()) {
            return new CuentaDAO().findByUsuarioAndTipo(conn, usuarioId, tipoCuenta);
        } catch (SQLException e) {
            logger.error("Error obteniendo cuentas usuario {} tipo {}", usuarioId, tipoCuenta, e);
            return new ArrayList<Cuenta>();
        }
    }

    @Override
    public Cuenta obtenerCuentaPorNumero(String numeroCuenta) {
        try (Connection conn = dataSource.getConnection()) {
            return new CuentaDAO().findByNumeroCuenta(conn, numeroCuenta);
        } catch (SQLException e) {
            logger.error("Error obteniendo cuenta {}", numeroCuenta, e);
            return null;
        }
    }
}
