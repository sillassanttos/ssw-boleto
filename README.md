# SSW Boleto


## API para Geração de Boleto, Arquivos de Remessa e Envio de Boletos por E-mail

Rotas: 

localhost:8883/ssw/boleto/status

localhost:8883/ssw/boleto/gerar/27/314597/0

localhost:8883/ssw/boleto/remessa/27/4

PUT

localhost:8883/ssw/boleto/enviar-email

Body: 

{
  "id_empresa": "27",
  "id_receber": "4",
  "parcela": "0",
  "destino": "meu-email@emaail.com.br"
}

Retorno:

{
  "sucesso": true,
  "mensagem": "E-mail realizado com sucesso."
}
