FROM public.ecr.aws/lambda/python:3.12

COPY ./webhook_lambda/requirements.txt ${LAMBDA_TASK_ROOT}/requirements.txt

RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt --target ${LAMBDA_TASK_ROOT}

COPY ./webhook_lambda/handler.py ${LAMBDA_TASK_ROOT}/handler.py
COPY ./shared/schemas.py ${LAMBDA_TASK_ROOT}/schemas.py

# Entry pt to hit for webhook lambda
CMD [ "handler.handler" ]