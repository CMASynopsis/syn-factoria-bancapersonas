package com.banca.model;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.Date;

public class Transferencia implements Serializable {
    private static final long serialVersionUID = 1L;

    private Long id;
    private String numeroOperacion;
    private String tipoTransferencia;
    private Long cuentaOrigenId;
    private String cuentaOrigenNumero;
    private Long cuentaDestinoId;
    private String cuentaDestinoNumero;
    private String cuentaDestinoCci;
    private String bancoDestino;
    private String titularDestino;
    private BigDecimal monto;
    private String moneda;
    private String glosa;
    private String estado;
    private String motivoRechazo;
    private Date fechaOperacion;
    private Date fechaValor;
    private Long usuarioId;

    public Transferencia() {}

    public String getTipoTransferenciaDescripcion() {
        if (tipoTransferencia == null) return "";
        switch (tipoTransferencia) {
            case "PROPIA":      return "Entre mis cuentas";
            case "MISMO_BANCO": return "Mismo banco";
            case "OTRO_BANCO":  return "Otro banco (CCI)";
            default:            return tipoTransferencia;
        }
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getNumeroOperacion() { return numeroOperacion; }
    public void setNumeroOperacion(String n) { this.numeroOperacion = n; }
    public String getTipoTransferencia() { return tipoTransferencia; }
    public void setTipoTransferencia(String t) { this.tipoTransferencia = t; }
    public Long getCuentaOrigenId() { return cuentaOrigenId; }
    public void setCuentaOrigenId(Long c) { this.cuentaOrigenId = c; }
    public String getCuentaOrigenNumero() { return cuentaOrigenNumero; }
    public void setCuentaOrigenNumero(String c) { this.cuentaOrigenNumero = c; }
    public Long getCuentaDestinoId() { return cuentaDestinoId; }
    public void setCuentaDestinoId(Long c) { this.cuentaDestinoId = c; }
    public String getCuentaDestinoNumero() { return cuentaDestinoNumero; }
    public void setCuentaDestinoNumero(String c) { this.cuentaDestinoNumero = c; }
    public String getCuentaDestinoCci() { return cuentaDestinoCci; }
    public void setCuentaDestinoCci(String c) { this.cuentaDestinoCci = c; }
    public String getBancoDestino() { return bancoDestino; }
    public void setBancoDestino(String b) { this.bancoDestino = b; }
    public String getTitularDestino() { return titularDestino; }
    public void setTitularDestino(String t) { this.titularDestino = t; }
    public BigDecimal getMonto() { return monto; }
    public void setMonto(BigDecimal m) { this.monto = m; }
    public String getMoneda() { return moneda; }
    public void setMoneda(String m) { this.moneda = m; }
    public String getGlosa() { return glosa; }
    public void setGlosa(String g) { this.glosa = g; }
    public String getEstado() { return estado; }
    public void setEstado(String e) { this.estado = e; }
    public String getMotivoRechazo() { return motivoRechazo; }
    public void setMotivoRechazo(String m) { this.motivoRechazo = m; }
    public Date getFechaOperacion() { return fechaOperacion; }
    public void setFechaOperacion(Date d) { this.fechaOperacion = d; }
    public Date getFechaValor() { return fechaValor; }
    public void setFechaValor(Date d) { this.fechaValor = d; }
    public Long getUsuarioId() { return usuarioId; }
    public void setUsuarioId(Long u) { this.usuarioId = u; }
}
