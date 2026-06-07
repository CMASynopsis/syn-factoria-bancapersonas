package com.banca.service;

import com.banca.dao.CuentaDAO;
import com.banca.dao.TransferenciaDAO;
import com.banca.model.Cuenta;
import com.banca.model.Transferencia;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import javax.annotation.Resource;
import javax.ejb.Stateless;
import javax.ejb.TransactionAttribute;
import javax.ejb.TransactionAttributeType;
import javax.sql.DataSource;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.UUID;

/**
 * EJB Stateless - Transferencias bancarias.
 *
 * Transacción gestionada por el CONTENEDOR WildFly 10.1 (CMT).
 * Al lanzar RuntimeException → WildFly hace rollback automático.
 *
 * DataSource: java:jboss/datasources/BancaDS → MySQL 5.7
 */
@Stateless
@TransactionAttribute(TransactionAttributeType.REQUIRED)
public class TransferenciaServiceBean implements TransferenciaServiceLocal {

    private static final Logger logger = LogManager.getLogger(TransferenciaServiceBean.class);

    @Resource(lookup = "java:jboss/datasources/BancaDS")
    private DataSource dataSource;

    // =====================================================
    // TRANSFERENCIA ENTRE CUENTAS PROPIAS
    // =====================================================
    @Override
    public TransferenciaResult transferirPropia(Long usuarioId, Long cuentaOrigenId,
                                                Long cuentaDestinoId, BigDecimal monto,
                                                String glosa) {
        if (cuentaOrigenId.equals(cuentaDestinoId))
            return new TransferenciaResult(false, "Origen y destino no pueden ser la misma cuenta.", null);
        if (monto == null || monto.compareTo(BigDecimal.ZERO) <= 0)
            return new TransferenciaResult(false, "El monto debe ser mayor a cero.", null);

        try (Connection conn = dataSource.getConnection()) {
            CuentaDAO cuentaDAO = new CuentaDAO();
            Cuenta origen  = cuentaDAO.findById(conn, cuentaOrigenId);
            Cuenta destino = cuentaDAO.findById(conn, cuentaDestinoId);

            if (origen == null || !origen.getUsuarioId().equals(usuarioId))
                return new TransferenciaResult(false, "Cuenta origen no válida.", null);
            if (destino == null || !destino.getUsuarioId().equals(usuarioId))
                return new TransferenciaResult(false, "Cuenta destino no válida.", null);
            if (!origen.getMoneda().equals(destino.getMoneda()))
                return new TransferenciaResult(false, "Las cuentas deben ser de la misma moneda.", null);
            if (origen.getSaldoDisponible().compareTo(monto) < 0)
                return new TransferenciaResult(false, "Saldo insuficiente en cuenta origen.", null);

            cuentaDAO.actualizarSaldo(conn, origen.getId(),
                    origen.getSaldo().subtract(monto),
                    origen.getSaldoDisponible().subtract(monto));
            cuentaDAO.actualizarSaldo(conn, destino.getId(),
                    destino.getSaldo().add(monto),
                    destino.getSaldoDisponible().add(monto));

            String nroOp = generarNroOp();
            Transferencia t = buildBase(nroOp, "PROPIA", origen, monto, usuarioId, glosa);
            t.setCuentaDestinoId(destino.getId());
            t.setCuentaDestinoNumero(destino.getNumeroCuenta());
            t.setTitularDestino(destino.getUsuarioNombre());
            new TransferenciaDAO().insertar(conn, t);

            logger.info("Transferencia PROPIA OK. Op: {}", nroOp);
            return new TransferenciaResult(true, "Transferencia realizada con éxito.", nroOp);

        } catch (SQLException e) {
            logger.error("Error SQL en transferencia propia", e);
            // RuntimeException → WildFly hace rollback automático
            throw new RuntimeException("Error al procesar la transferencia.", e);
        }
    }

    // =====================================================
    // TRANSFERENCIA MISMO BANCO
    // =====================================================
    @Override
    public TransferenciaResult transferirMismoBanco(Long usuarioId, Long cuentaOrigenId,
                                                     String numeroCuentaDestino,
                                                     BigDecimal monto, String glosa) {
        if (monto == null || monto.compareTo(BigDecimal.ZERO) <= 0)
            return new TransferenciaResult(false, "El monto debe ser mayor a cero.", null);
        if (numeroCuentaDestino == null || numeroCuentaDestino.trim().isEmpty())
            return new TransferenciaResult(false, "Número de cuenta destino requerido.", null);

        try (Connection conn = dataSource.getConnection()) {
            CuentaDAO cuentaDAO = new CuentaDAO();
            Cuenta origen  = cuentaDAO.findById(conn, cuentaOrigenId);
            Cuenta destino = cuentaDAO.findByNumeroCuenta(conn, numeroCuentaDestino.trim());

            if (origen == null || !origen.getUsuarioId().equals(usuarioId))
                return new TransferenciaResult(false, "Cuenta origen no válida.", null);
            if (origen.getNumeroCuenta().equals(numeroCuentaDestino.trim()))
                return new TransferenciaResult(false, "No puede transferir a la misma cuenta.", null);
            if (destino == null)
                return new TransferenciaResult(false, "Cuenta destino no encontrada en Banco Nacional.", null);
            if (origen.getSaldoDisponible().compareTo(monto) < 0)
                return new TransferenciaResult(false, "Saldo insuficiente.", null);

            cuentaDAO.actualizarSaldo(conn, origen.getId(),
                    origen.getSaldo().subtract(monto),
                    origen.getSaldoDisponible().subtract(monto));
            cuentaDAO.actualizarSaldo(conn, destino.getId(),
                    destino.getSaldo().add(monto),
                    destino.getSaldoDisponible().add(monto));

            String nroOp = generarNroOp();
            Transferencia t = buildBase(nroOp, "MISMO_BANCO", origen, monto, usuarioId, glosa);
            t.setCuentaDestinoId(destino.getId());
            t.setCuentaDestinoNumero(destino.getNumeroCuenta());
            t.setTitularDestino(destino.getUsuarioNombre());
            t.setBancoDestino("Banco Nacional");
            new TransferenciaDAO().insertar(conn, t);

            logger.info("Transferencia MISMO_BANCO OK. Op: {}", nroOp);
            return new TransferenciaResult(true, "Transferencia realizada con éxito.", nroOp);

        } catch (SQLException e) {
            logger.error("Error SQL en transferencia mismo banco", e);
            throw new RuntimeException("Error al procesar la transferencia.", e);
        }
    }

    // =====================================================
    // TRANSFERENCIA OTRO BANCO (CCI)
    // =====================================================
    @Override
    public TransferenciaResult transferirOtroBanco(Long usuarioId, Long cuentaOrigenId,
                                                    String cciDestino, String titularDestino,
                                                    String bancoDestino, BigDecimal monto,
                                                    String glosa) {
        if (monto == null || monto.compareTo(BigDecimal.ZERO) <= 0)
            return new TransferenciaResult(false, "El monto debe ser mayor a cero.", null);
        if (cciDestino == null || cciDestino.trim().length() != 20)
            return new TransferenciaResult(false, "El CCI debe tener exactamente 20 dígitos.", null);
        if (titularDestino == null || titularDestino.trim().isEmpty())
            return new TransferenciaResult(false, "El nombre del titular destino es requerido.", null);
        if (monto.compareTo(new BigDecimal("50000")) > 0)
            return new TransferenciaResult(false, "Monto supera el límite de S/ 50,000 para transferencias interbancarias.", null);

        try (Connection conn = dataSource.getConnection()) {
            CuentaDAO cuentaDAO = new CuentaDAO();
            Cuenta origen = cuentaDAO.findById(conn, cuentaOrigenId);

            if (origen == null || !origen.getUsuarioId().equals(usuarioId))
                return new TransferenciaResult(false, "Cuenta origen no válida.", null);
            if (origen.getSaldoDisponible().compareTo(monto) < 0)
                return new TransferenciaResult(false, "Saldo insuficiente.", null);

            cuentaDAO.actualizarSaldo(conn, origen.getId(),
                    origen.getSaldo().subtract(monto),
                    origen.getSaldoDisponible().subtract(monto));

            String nroOp = generarNroOp();
            Transferencia t = buildBase(nroOp, "OTRO_BANCO", origen, monto, usuarioId, glosa);
            t.setCuentaDestinoCci(cciDestino.trim());
            t.setTitularDestino(titularDestino.trim());
            t.setBancoDestino(bancoDestino.trim());
            new TransferenciaDAO().insertar(conn, t);

            logger.info("Transferencia OTRO_BANCO OK. Op: {}", nroOp);
            return new TransferenciaResult(true, "Transferencia interbancaria enviada con éxito.", nroOp);

        } catch (SQLException e) {
            logger.error("Error SQL en transferencia otro banco", e);
            throw new RuntimeException("Error al procesar la transferencia.", e);
        }
    }

    // =====================================================
    // HELPERS
    // =====================================================
    private Transferencia buildBase(String nroOp, String tipo, Cuenta origen,
                                     BigDecimal monto, Long usuarioId, String glosa) {
        Transferencia t = new Transferencia();
        t.setNumeroOperacion(nroOp);
        t.setTipoTransferencia(tipo);
        t.setCuentaOrigenId(origen.getId());
        t.setCuentaOrigenNumero(origen.getNumeroCuenta());
        t.setMonto(monto);
        t.setMoneda(origen.getMoneda());
        t.setGlosa(glosa != null && !glosa.trim().isEmpty() ? glosa.trim() : tipo);
        t.setEstado("PROCESADA");
        t.setUsuarioId(usuarioId);
        return t;
    }

    private String generarNroOp() {
        return UUID.randomUUID().toString().replace("-", "").substring(0, 16).toUpperCase();
    }
}
