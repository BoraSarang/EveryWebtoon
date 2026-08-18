from abc import ABC, abstractmethod

from models import WebtoonInfo


class DiscoveryProvider(ABC):
    @abstractmethod
    async def discover(
        self, category: str, **params
    ) -> list[WebtoonInfo]:
        ...
