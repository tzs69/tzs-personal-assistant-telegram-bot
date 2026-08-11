FROM public.ecr.aws/lambda/python:3.12

COPY ./lambdas/invoker/requirements.txt ${LAMBDA_TASK_ROOT}/requirements.txt

RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt --target ${LAMBDA_TASK_ROOT}

COPY ./lambdas/invoker/handler.py ${LAMBDA_TASK_ROOT}/handler.py
COPY ./shared/schemas.py ${LAMBDA_TASK_ROOT}/schemas.py

# Entry pt to hit for webhook lambda
CMD [ "handler.handler" ]
