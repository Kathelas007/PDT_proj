import time
import logging


class FncTimer:
    measured_fnc = {}

    @staticmethod
    def measure(fnc):
        start = time.time()

        def inner(*args, **kwargs):
            return fnc(*args, **kwargs)

        end = time.time()
        FncTimer.measured_fnc[fnc.__name__] = end - start
        return inner

    @staticmethod
    def print_statistics():
        for fnc_name, measured_time in FncTimer.measured_fnc.items():
            minutes = measured_time // 60
            seconds = measured_time - minutes * 60
            # print(f"{fnc_name}: {minutes} min {seconds} s")
            logging.debug(f"{fnc_name}: {measured_time} s")


@FncTimer.measure
def foo():
    print('foo')


@FncTimer.measure
def goo():
    print('goo')


if __name__ == "__main__":
    # test timer
    logging.basicConfig(level=logging.DEBUG)
    FncTimer.print_statistics()
