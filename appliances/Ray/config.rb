# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require 'erb'
require 'yaml'

# These variables are not exposed to the user and only used during install
ONEAPP_RAY_CONFIGFILE_TEMPLATE_PATH = env \
    :ONEAPP_RAY_CONFIGFILE_TEMPLATE_PATH,
    '/etc/one-appliance/service.d/Ray/config.yaml.template'

ONEAPP_RAY_MODULES = env :ONEAPP_RAY_MODULES, 'default,serve'
ONEAPP_RAY_PORT    = env :ONEAPP_RAY_PORT, '6379'

# This path will contain the generated model.py file, it will be added to PYTHONPATH
ONEAPP_RAY_GENERATED_FILES_PATH = env \
    :ONEAPP_RAY_GENERATED_FILES_PATH,
    '/etc/one-appliance/service.d/Ray'

# ------------------------------------------------------------------------------
# Configuration file for Ray
# ------------------------------------------------------------------------------
ONEAPP_RAY_CONFIGFILE_DEST_PATH = env \
    :ONEAPP_RAY_CONFIGFILE_DEST_PATH,
    "#{ONEAPP_RAY_GENERATED_FILES_PATH}/config.yaml"

ONEAPP_RAY_CONFIG_FILE   = env :ONEAPP_RAY_CONFIG_FILE, ''
ONEAPP_RAY_CONFIG_FILE64 = env :ONEAPP_RAY_CONFIG_FILE64, ''

# ------------------------------------------------------------------------------
# Application to deploy in Ray
# ------------------------------------------------------------------------------
ONEAPP_RAY_APPLICATION_DEST_PATH = env \
    :ONEAPP_RAY_APPLICATION_DEST_PATH,
    "#{ONEAPP_RAY_GENERATED_FILES_PATH}/model.py"

ONEAPP_RAY_APPLICATION_URL    = env :ONEAPP_AI_APPLICATION_URL, ''
ONEAPP_RAY_APPLICATION_FILE   = env :ONEAPP_AI_APPLICATION_FILE, ''
ONEAPP_RAY_APPLICATION_FILE64 = env :ONEAPP_AI_APPLICATION_FILE64, ''

ONEAPP_RAY_APPLICATION_DEFAULT=<<~EOM
    import ray
    from ray import serve
    from fastapi import FastAPI
    from transformers import pipeline, AutoModelForCausalLM, AutoTokenizer
    from ray.serve.handle import DeploymentHandle
    from typing import Dict
    from ray.serve import Application
    import torch

    app = FastAPI()

    @serve.deployment
    @serve.ingress(app)
    class ChatBot:
        def __init__(self, model_id: str, token:str, temperature: float, system_prompt: str):
            # Load model
            self.device = "cuda:0" if torch.cuda.is_available() else "cpu"
            self.tokenizer = AutoTokenizer.from_pretrained(
                model_id, token=token)
            self.model = AutoModelForCausalLM.from_pretrained(
                model_id, token=token).to(self.device)
            self.temperature = temperature
            self.system_prompt = system_prompt
            # Check if there is chat_template
            if self.tokenizer.chat_template is None:
                self.tokenizer.chat_template = """
                    {% if not add_generation_prompt is defined %}
                        {% set add_generation_prompt = false %}
                    {% endif %}
                    {% for message in messages %}
                        {{ '<|im_start|>' + message['role'] + '\n' + message['content'] + '<|im_end|>\n' }}
                    {% endfor %}
                    {% if add_generation_prompt %}
                        {{ '<|im_start|>assistant\n' }}
                    {% endif %}
                """

        @app.post("/chat")
        def chat(self, text: str) -> str:
            messages = [
                {"role": "system", "content": self.system_prompt},
                {"role": "user", "content": text}]

            # Tokenize the text
            chat = self.tokenizer.apply_chat_template(
                messages, tokenize=False, add_generation_prompt=True, return_tensors="pt")
            input_tokens = self.tokenizer(chat, return_tensors="pt").to(self.device)

            # Run inference
            output = self.model.generate(
                **input_tokens,
                max_new_tokens=1024)

            # Decode output tokens into text
            output = self.tokenizer.batch_decode(output)
            answer = output[0].split('<|end_header_id|>')[-1][:-10]
            return answer


    def app_builder(args: Dict[str, str]) -> Application:
        return ChatBot.bind(args["model_id"], args['token'], args['temperature'], args['system_prompt'])
EOM

# ------------------------------------------------------------------------------
# Configuration parameters for API and inference model
# ------------------------------------------------------------------------------
ONEAPP_RAY_API_PORT  = env :ONEAPP_RAY_API_PORT, '8000'
ONEAPP_RAY_API_ROUTE = env :ONEAPP_RAY_API_ROUTE, '/chat'

ONEAPP_RAY_MODEL_ID          = env :ONEAPP_RAY_MODEL_ID, 'meta-llama/Llama-3.2-1B-Instruct'
ONEAPP_RAY_MODEL_TOKEN       = env :ONEAPP_RAY_MODEL_TOKEN, ''
ONEAPP_RAY_MODEL_TEMPERATURE = env :ONEAPP_RAY_MODEL_TEMPERATURE, '0.1'
ONEAPP_RAY_MODEL_PROMPT      = env :ONEAPP_RAY_MODEL_PROMPT, \
                                   'You are a helpful assisstant. Answer the question.'
# ------------------------------------------------------------------------------
# Not exposed parameters, this should be computed from VCPU
# ------------------------------------------------------------------------------
ONEAPP_RAY_CHATBOT_REPLICAS = env :ONEAPP_RAY_CHATBOT_REPLICAS, '1'
ONEAPP_RAY_CHATBOT_CPUS     = env :ONEAPP_RAY_CHATBOT_CPUS, '5.0'

def gen_template_config(template_path = ONEAPP_RAY_CONFIGFILE_TEMPLATE_PATH,
                        config_path = ONEAPP_RAY_CONFIGFILE_DEST_PATH)
    template = File.read(template_path)

    erb    = ERB.new(template)
    result = erb.result(binding)

    write_file(config_path, result)
end

def write_file(path, content, permissions = 0o644)
    File.open(path, 'w', permissions) do |file|
        file.write(content)
    end
end
