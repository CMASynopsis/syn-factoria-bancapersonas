<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Banco Nacional - Transferencia entre mis cuentas</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/style.css">
</head>
<body>
<jsp:include page="../header.jsp"/>

<main class="main-content">
    <div class="page-header">
        <a href="${pageContext.request.contextPath}/home" class="back-link">← Volver</a>
        <h1>🔄 Transferencia entre mis cuentas</h1>
        <p class="page-subtitle">Mueve dinero entre tus propias cuentas sin costo</p>
    </div>

    <div class="form-container">
        <c:if test="${not empty exito}">
            <div class="alert alert-success">
                <strong>✓ ${exito}</strong><br>
                Número de operación: <strong>${numeroOperacion}</strong>
            </div>
        </c:if>
        <c:if test="${not empty error}">
            <div class="alert alert-error">⚠ ${error}</div>
        </c:if>

        <form method="POST" action="${pageContext.request.contextPath}/transferencia/propia" class="transfer-form">
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

            <div class="form-group">
                <label for="cuentaDestinoId">Cuenta Destino</label>
                <select name="cuentaDestinoId" id="cuentaDestinoId" required>
                    <option value="">-- Seleccione cuenta de destino --</option>
                    <c:forEach var="c" items="${cuentas}">
                        <option value="${c.id}">
                            ${c.tipoCuenta} ${c.numeroCuentaFormateado} | ${c.moneda}
                        </option>
                    </c:forEach>
                </select>
            </div>

            <div class="form-group">
                <label for="monto">Monto</label>
                <div class="input-prefix-wrapper">
                    <span class="input-prefix" id="currencyPrefix">S/</span>
                    <input type="number" name="monto" id="monto"
                           step="0.01" min="0.01" max="999999.99"
                           placeholder="0.00" required/>
                </div>
            </div>

            <div class="form-group">
                <label for="glosa">Glosa / Referencia <span class="optional">(opcional)</span></label>
                <input type="text" name="glosa" id="glosa"
                       placeholder="Descripción de la transferencia" maxlength="200"/>
            </div>

            <div class="form-actions">
                <a href="${pageContext.request.contextPath}/home" class="btn btn-outline">Cancelar</a>
                <button type="submit" class="btn btn-primary">Transferir</button>
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
    } else {
        info.textContent = '';
    }
});
</script>
</body>
</html>
