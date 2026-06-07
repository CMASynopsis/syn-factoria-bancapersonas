<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Banco Nacional - Transferencia a otro banco</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/style.css">
</head>
<body>
<jsp:include page="../header.jsp"/>

<main class="main-content">
    <div class="page-header">
        <a href="${pageContext.request.contextPath}/home" class="back-link">← Volver</a>
        <h1>🌐 Transferencia a otro banco</h1>
        <p class="page-subtitle">Transferencia interbancaria mediante CCI (Código de Cuenta Interbancario)</p>
    </div>

    <div class="form-container">
        <c:if test="${not empty exito}">
            <div class="alert alert-success">
                <strong>✓ ${exito}</strong><br>
                Número de operación: <strong>${numeroOperacion}</strong><br>
                <small>La transferencia puede demorar hasta 24 horas hábiles en acreditarse.</small>
            </div>
        </c:if>
        <c:if test="${not empty error}">
            <div class="alert alert-error">⚠ ${error}</div>
        </c:if>

        <form method="POST" action="${pageContext.request.contextPath}/transferencia/otro-banco" class="transfer-form">

            <fieldset class="form-fieldset">
                <legend>Datos de origen</legend>
                <div class="form-group">
                    <label for="cuentaOrigenId">Cuenta Origen</label>
                    <select name="cuentaOrigenId" id="cuentaOrigenId" required>
                        <option value="">-- Seleccione cuenta de origen --</option>
                        <c:forEach var="c" items="${cuentas}">
                            <option value="${c.id}" data-saldo="${c.saldoDisponible}" data-moneda="${c.moneda}">
                                ${c.tipoCuenta} ${c.numeroCuentaFormateado} |
                                Saldo: ${c.moneda} <fmt:formatNumber value="${c.saldoDisponible}" minFractionDigits="2"/>
                            </option>
                        </c:forEach>
                    </select>
                    <div class="saldo-info" id="saldoOrigen"></div>
                </div>
            </fieldset>

            <fieldset class="form-fieldset">
                <legend>Datos del destinatario</legend>

                <div class="form-group">
                    <label for="bancoDestino">Banco Destino</label>
                    <select name="bancoDestino" id="bancoDestino" required>
                        <option value="">-- Seleccione banco --</option>
                        <c:forEach var="banco" items="${bancos}">
                            <option value="${banco}">${banco}</option>
                        </c:forEach>
                    </select>
                </div>

                <div class="form-group">
                    <label for="cciDestino">CCI - Código de Cuenta Interbancario</label>
                    <input type="text" name="cciDestino" id="cciDestino"
                           placeholder="20 dígitos del CCI" maxlength="20" minlength="20"
                           pattern="[0-9]{20}" required/>
                    <small class="field-hint">El CCI tiene 20 dígitos. Lo encuentras en tu cartilla de cuenta.</small>
                </div>

                <div class="form-group">
                    <label for="titularDestino">Nombre del titular</label>
                    <input type="text" name="titularDestino" id="titularDestino"
                           placeholder="Nombre completo del titular" maxlength="150" required/>
                </div>
            </fieldset>

            <fieldset class="form-fieldset">
                <legend>Datos de la operación</legend>

                <div class="form-group">
                    <label for="monto">Monto</label>
                    <div class="input-prefix-wrapper">
                        <span class="input-prefix" id="currencyPrefix">S/</span>
                        <input type="number" name="monto" id="monto"
                               step="0.01" min="0.01" max="50000.00"
                               placeholder="0.00" required/>
                    </div>
                    <small class="field-hint">Límite: S/ 50,000.00 por operación</small>
                </div>

                <div class="form-group">
                    <label for="glosa">Glosa / Referencia <span class="optional">(opcional)</span></label>
                    <input type="text" name="glosa" id="glosa"
                           placeholder="Motivo de la transferencia" maxlength="200"/>
                </div>
            </fieldset>

            <div class="info-box info-warning">
                <strong>⚠ Importante:</strong> Las transferencias interbancarias se procesan
                en el próximo ciclo de liquidación. El plazo de acreditación es de hasta
                24 horas hábiles. Verifique bien los datos antes de confirmar.
            </div>

            <div class="form-actions">
                <a href="${pageContext.request.contextPath}/home" class="btn btn-outline">Cancelar</a>
                <button type="submit" class="btn btn-primary">Enviar transferencia</button>
            </div>
        </form>
    </div>
</main>

<script>
document.getElementById('cuentaOrigenId').addEventListener('change', function() {
    var opt = this.options[this.selectedIndex];
    var saldo = opt.getAttribute('data-saldo');
    var moneda = opt.getAttribute('data-moneda');
    var info = document.getElementById('saldoOrigen');
    if (saldo) {
        info.textContent = 'Saldo disponible: ' + (moneda === 'USD' ? '$' : 'S/') + ' ' + parseFloat(saldo).toFixed(2);
        document.getElementById('currencyPrefix').textContent = moneda === 'USD' ? '$' : 'S/';
    } else { info.textContent = ''; }
});
document.getElementById('cciDestino').addEventListener('input', function() {
    this.value = this.value.replace(/\D/g, '');
});
</script>
</body>
</html>
