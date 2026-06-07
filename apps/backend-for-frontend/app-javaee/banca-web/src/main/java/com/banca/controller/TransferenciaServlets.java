package com.banca.controller;

import com.banca.model.Usuario;
import com.banca.service.CuentaServiceLocal;
import com.banca.service.TransferenciaServiceLocal;

import javax.ejb.EJB;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.math.BigDecimal;

// -------------------------------------------------------
// TRANSFERENCIA ENTRE CUENTAS PROPIAS
// -------------------------------------------------------
@WebServlet("/transferencia/propia")
class TransferenciaPropiaCuentaServlet extends HttpServlet {

    @EJB private TransferenciaServiceLocal transferenciaService;
    @EJB private CuentaServiceLocal cuentaService;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {
        cargar(req);
        req.getRequestDispatcher("/WEB-INF/views/transferencia/propia.jsp").forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {
        Usuario u = (Usuario) req.getSession().getAttribute("usuario");
        try {
            Long origenId  = Long.parseLong(req.getParameter("cuentaOrigenId"));
            Long destinoId = Long.parseLong(req.getParameter("cuentaDestinoId"));
            BigDecimal monto = new BigDecimal(req.getParameter("monto").replace(",", ""));
            String glosa = req.getParameter("glosa");

            TransferenciaServiceLocal.TransferenciaResult r =
                transferenciaService.transferirPropia(u.getId(), origenId, destinoId, monto, glosa);

            if (r.isExitoso()) {
                req.setAttribute("exito", r.getMensaje());
                req.setAttribute("numeroOperacion", r.getNumeroOperacion());
            } else {
                req.setAttribute("error", r.getMensaje());
            }
        } catch (Exception e) {
            req.setAttribute("error", "Datos inválidos. Verifique el formulario.");
        }
        cargar(req);
        req.getRequestDispatcher("/WEB-INF/views/transferencia/propia.jsp").forward(req, res);
    }

    private void cargar(HttpServletRequest req) {
        Usuario u = (Usuario) req.getSession().getAttribute("usuario");
        req.setAttribute("cuentas", cuentaService.obtenerCuentasUsuario(u.getId()));
    }
}


// -------------------------------------------------------
// TRANSFERENCIA MISMO BANCO
// -------------------------------------------------------
@WebServlet("/transferencia/mismo-banco")
class TransferenciaMismoBancoServlet extends HttpServlet {

    @EJB private TransferenciaServiceLocal transferenciaService;
    @EJB private CuentaServiceLocal cuentaService;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {
        cargar(req);
        req.getRequestDispatcher("/WEB-INF/views/transferencia/mismo-banco.jsp").forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {
        Usuario u = (Usuario) req.getSession().getAttribute("usuario");
        try {
            Long origenId = Long.parseLong(req.getParameter("cuentaOrigenId"));
            String nroCuentaDestino = req.getParameter("numeroCuentaDestino");
            BigDecimal monto = new BigDecimal(req.getParameter("monto").replace(",", ""));
            String glosa = req.getParameter("glosa");

            TransferenciaServiceLocal.TransferenciaResult r =
                transferenciaService.transferirMismoBanco(u.getId(), origenId, nroCuentaDestino, monto, glosa);

            if (r.isExitoso()) {
                req.setAttribute("exito", r.getMensaje());
                req.setAttribute("numeroOperacion", r.getNumeroOperacion());
            } else {
                req.setAttribute("error", r.getMensaje());
            }
        } catch (Exception e) {
            req.setAttribute("error", "Datos inválidos. Verifique el formulario.");
        }
        cargar(req);
        req.getRequestDispatcher("/WEB-INF/views/transferencia/mismo-banco.jsp").forward(req, res);
    }

    private void cargar(HttpServletRequest req) {
        Usuario u = (Usuario) req.getSession().getAttribute("usuario");
        req.setAttribute("cuentas", cuentaService.obtenerCuentasUsuario(u.getId()));
    }
}


// -------------------------------------------------------
// TRANSFERENCIA OTRO BANCO (CCI)
// -------------------------------------------------------
@WebServlet("/transferencia/otro-banco")
class TransferenciaOtroBancoServlet extends HttpServlet {

    @EJB private TransferenciaServiceLocal transferenciaService;
    @EJB private CuentaServiceLocal cuentaService;

    private static final String[] BANCOS = {
        "BCP - Banco de Crédito del Perú", "BBVA Perú", "Interbank",
        "Scotiabank Perú", "BanBif", "Banco Pichincha",
        "Mibanco", "Banco GNB Perú", "Banco Falabella",
        "Banco Ripley", "Caja Trujillo", "Caja Arequipa", "Caja Piura"
    };

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {
        cargar(req);
        req.getRequestDispatcher("/WEB-INF/views/transferencia/otro-banco.jsp").forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {
        Usuario u = (Usuario) req.getSession().getAttribute("usuario");
        try {
            Long origenId        = Long.parseLong(req.getParameter("cuentaOrigenId"));
            String cciDestino    = req.getParameter("cciDestino");
            String titular       = req.getParameter("titularDestino");
            String banco         = req.getParameter("bancoDestino");
            BigDecimal monto     = new BigDecimal(req.getParameter("monto").replace(",", ""));
            String glosa         = req.getParameter("glosa");

            TransferenciaServiceLocal.TransferenciaResult r =
                transferenciaService.transferirOtroBanco(u.getId(), origenId,
                    cciDestino, titular, banco, monto, glosa);

            if (r.isExitoso()) {
                req.setAttribute("exito", r.getMensaje());
                req.setAttribute("numeroOperacion", r.getNumeroOperacion());
            } else {
                req.setAttribute("error", r.getMensaje());
            }
        } catch (Exception e) {
            req.setAttribute("error", "Datos inválidos. Verifique el formulario.");
        }
        cargar(req);
        req.getRequestDispatcher("/WEB-INF/views/transferencia/otro-banco.jsp").forward(req, res);
    }

    private void cargar(HttpServletRequest req) {
        Usuario u = (Usuario) req.getSession().getAttribute("usuario");
        req.setAttribute("cuentas", cuentaService.obtenerCuentasUsuario(u.getId()));
        req.setAttribute("bancos", BANCOS);
    }
}
