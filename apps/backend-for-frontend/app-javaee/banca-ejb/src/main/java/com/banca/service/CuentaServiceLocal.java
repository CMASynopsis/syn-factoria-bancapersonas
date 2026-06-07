package com.banca.service;

import com.banca.model.Cuenta;
import java.util.List;

public interface CuentaServiceLocal {
    List<Cuenta> obtenerCuentasUsuario(Long usuarioId);
    List<Cuenta> obtenerCuentasUsuarioPorTipo(Long usuarioId, String tipoCuenta);
    Cuenta obtenerCuentaPorNumero(String numeroCuenta);
}
