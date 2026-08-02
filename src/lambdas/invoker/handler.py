import logging

logger = logging.getLogger(__name__)


def handler(event, context):
    logger.error("Invoker Lambda is not implemented")
    raise RuntimeError("Invoker Lambda is not implemented")