package com.banca.service;

import java.math.BigDecimal;

public interface TransferenciaServiceLocal {

    class TransferenciaResult {
        private final boolean exitoso;
        private final String mensaje;
        private final String numeroOperacion;

        public TransferenciaResult(boolean exitoso, String mensaje, String numeroOperacion) {
            this.exitoso = exitoso;
            this.mensaje = mensaje;
            this.numeroOperacion = numeroOperacion;
        }
        public boolean isExitoso()          { return exitoso; }
        public String getMensaje()          { return mensaje; }
        public String getNumeroOperacion()  { return numeroOperacion; }
    }

    TransferenciaResult transferirPropia(Long usuarioId, Long cuentaOrigenId,
                                         Long cuentaDestinoId, BigDecimal monto, String glosa);

    TransferenciaResult transferirMismoBanco(Long usuarioId, Long cuentaOrigenId,
                                              String numeroCuentaDestino, BigDecimal monto, String glosa);

    TransferenciaResult transferirOtroBanco(Long usuarioId, Long cuentaOrigenId,
                                             String cciDestino, String titularDestino,
                                             String bancoDestino, BigDecimal monto, String glosa);
}
