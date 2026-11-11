import json
from types import SimpleNamespace
from unittest.mock import Mock
import pytest
from schemas import CategorizeRequest, ChatbotRequest
from services import AIServiceError, ChatbotService


def result(content):
    return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=content))])


def test_rejects_out_of_scope():
    client = Mock()
    client.chat.completions.create.return_value = result('false')
    service = ChatbotService(client, 'classify', 'fibo')
    response = service.chatbot(ChatbotRequest(message='fora'))
    assert response.erro == '1'
    assert client.chat.completions.create.call_count == 1


def test_success():
    client = Mock()
    client.chat.completions.create.side_effect = [result('true'), result('{"response":"ok"}')]
    service = ChatbotService(client, 'classify', 'fibo')
    response = service.chatbot(ChatbotRequest(message='oi'))
    assert response.erro == '0'
    assert response.reply == 'ok'
    assert response.response == 'ok'
    assert client.chat.completions.create.call_count == 2


def test_invalid_classifier_does_not_approve(monkeypatch):
    monkeypatch.setattr('services.CLASSIFIER_MODELS', ['test-model'])
    client = Mock()
    client.chat.completions.create.return_value = result('talvez')
    service = ChatbotService(client, 'classify', 'fibo')
    with pytest.raises(AIServiceError):
        service.chatbot(ChatbotRequest(message='oi'))


def test_categorize_with_payment_method():
    client = Mock()
    client.chat.completions.create.return_value = result(json.dumps({
        'category': 'Saúde',
        'confidence': 0.94,
        'normalized_description': 'Academia SmartFit',
        'estimated_amount': 129.90,
        'budget_tip': 'Lembre-se de considerar esta assinatura fixa no limite de 50%-80% do cartão.',
        'payment_method': 'Crédito',
    }))
    service = ChatbotService(client, 'classify', 'fibo', 'categorize', 'ocr')
    res = service.categorize(CategorizeRequest(description='Academia 129,90 no cartão', amount=129.90))
    assert res.category == 'Saúde'
    assert res.payment_method == 'Crédito'
    assert res.estimated_amount == 129.90


def test_ocr_flexible_date():
    client = Mock()
    client.chat.completions.create.return_value = result(json.dumps({
        'merchant': 'Sabesp Boleto',
        'amount': 85.50,
        'date': '15/11/2026',
        'category': 'Moradia',
        'confidence': 0.91,
        'budget_tip': 'Programe alertas 2x ao dia para não esquecer o vencimento.',
        'payment_method': 'Boleto',
    }))
    service = ChatbotService(client, 'classify', 'fibo', 'categorize', 'ocr')
    res = service.ocr(b'\xff\xd8\xff\xe0test', 'image/jpeg')
    assert res.merchant == 'Sabesp Boleto'
    assert res.payment_method == 'Boleto'
    assert res.date is not None and res.date.day == 15 and res.date.month == 11


def test_chat_with_conversation_history():
    from schemas import ChatTurn
    client = Mock()
    client.chat.completions.create.side_effect = [
        result('true'),
        result('{"response":"Gastando R$ 900 você usa 60% do limite de R$ 1.500, dentro da faixa saudável de 50% a 80%."}'),
    ]
    service = ChatbotService(client, 'classify', 'fibo')
    req = ChatbotRequest(
        message='E se eu gastar 900?',
        history=[
            ChatTurn(role='user', content='Tenho 1500 de limite no cartão'),
            ChatTurn(role='assistant', content='O ideal é manter entre R$ 750 (50%) e R$ 1.200 (80%).'),
        ],
    )
    response = service.chatbot(req)
    assert response.erro == '0'
    assert '60%' in response.reply
    fibo_call_messages = client.chat.completions.create.call_args_list[1].kwargs['messages']
    assert len(fibo_call_messages) == 4
