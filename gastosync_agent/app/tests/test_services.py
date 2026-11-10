import json
from types import SimpleNamespace
from unittest.mock import Mock
import pytest
from schemas import ChatbotRequest
from services import ChatbotService, AIServiceError

def result(content):
    return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=content))])

def test_rejects_out_of_scope():
    client = Mock()
    client.chat.completions.create.return_value = result('false')
    service = ChatbotService(client, 'classify', 'fibo')
    response = service.chatbot(ChatbotRequest(user='u', prompt='fora', session=1))
    assert response.erro == '1'
    assert client.chat.completions.create.call_count == 1

def test_success():
    client = Mock()
    client.chat.completions.create.side_effect = [result('true'), result('{"answer":"ok"}')]
    service = ChatbotService(client, 'classify', 'fibo')
    response = service.chatbot(ChatbotRequest(user='u', prompt='oi', session=1))
    assert response.erro == '0'
    assert json.loads(response.chabot_response) == {'answer': 'ok'}
    assert client.chat.completions.create.call_count == 2

def test_invalid_classifier_does_not_approve(monkeypatch):
    monkeypatch.setattr('services.CLASSIFIER_MODELS', ['test-model'])
    client = Mock()
    client.chat.completions.create.return_value = result('talvez')
    service = ChatbotService(client, 'classify', 'fibo')
    with pytest.raises(AIServiceError):
        service.chatbot(ChatbotRequest(user='u', prompt='oi', session=1))
