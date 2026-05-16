# test_wikipedia.py
import time
import json
import os
import pytest
from pathlib import Path
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.edge.options import Options as EdgeOptions
from selenium.webdriver.firefox.options import Options as FirefoxOptions
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException

EMAIL = "Selenium (software)"
PASSWORD = ""

SCREENSHOTS_DIR = Path("screenshots")
COOKIES_FILE = Path("cookies.txt")
SCREENSHOTS_DIR.mkdir(exist_ok=True)


class BasePage:
    def __init__(self, driver):
        self.driver = driver
        self.wait = WebDriverWait(driver, 20)
        self._step = 0

    def _shot(self, label: str):
        self._step += 1
        path = SCREENSHOTS_DIR / f"{self._step:02d}_{label}.png"
        self.driver.save_screenshot(str(path))
        print(f"  screenshot: {path.name}")

    def _wait_click(self, css: str, timeout: int = 20):
        el = WebDriverWait(self.driver, timeout).until(
            EC.element_to_be_clickable((By.CSS_SELECTOR, css))
        )
        el.click()
        return el

    def save_cookies(self):
        cookies = self.driver.get_cookies()
        with open(COOKIES_FILE, "w", encoding="utf-8") as f:
            for c in cookies:
                f.write(json.dumps(c) + "\n")
        print(f"  cookies saved: {len(cookies)} -> {COOKIES_FILE}")


class LoginPage(BasePage):
    URL = "https://www.wikipedia.org/"

    def open(self):
        self.driver.get(self.URL)
        WebDriverWait(self.driver, 20).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "#searchInput"))
        )
        self._shot("login_page")

    def login(self, email: str, password: str):
        search = self.driver.find_element(By.CSS_SELECTOR, "#searchInput")
        search.send_keys(email)
        self._shot("credentials_filled")
        search.send_keys(Keys.ENTER)


class AppPage(BasePage):
    def wait_for_load(self):
        WebDriverWait(self.driver, 30).until(lambda d: "/wiki/" in d.current_url)
        WebDriverWait(self.driver, 20).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "#firstHeading"))
        )
        time.sleep(1)
        self._shot("app_loaded")

    def go_to_inbox(self):
        self.driver.get("https://en.wikipedia.org/wiki/Main_Page")
        WebDriverWait(self.driver, 15).until(lambda d: "Main_Page" in d.current_url)
        time.sleep(1)
        self._shot("inbox")

    def go_to_today(self):
        self.driver.get("https://en.wikipedia.org/wiki/Special:Random")
        WebDriverWait(self.driver, 15).until(lambda d: "/wiki/" in d.current_url)
        time.sleep(1)
        self._shot("today_view")

    def add_task(self, name: str):
        print(f"\n  Searching article: {name!r}")
        editor = WebDriverWait(self.driver, 10).until(
            EC.visibility_of_element_located((By.CSS_SELECTOR, "#searchInput"))
        )
        editor.click()
        editor.send_keys(Keys.CONTROL, "a")
        editor.send_keys(Keys.BACKSPACE)
        self._shot("task_editor_open")
        editor.send_keys(name)
        self._shot("task_name_typed")
        editor.send_keys(Keys.ENTER)
        WebDriverWait(self.driver, 10).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "#firstHeading"))
        )
        time.sleep(0.8)
        self._shot("task_submitted")
        print(f"  article loaded: {name!r}")

    def complete_first_task(self):
        task_row = WebDriverWait(self.driver, 10).until(
            EC.presence_of_element_located(
                (By.CSS_SELECTOR, '#mw-content-text a[href^="/wiki/"]')
            )
        )
        ActionChains(self.driver).move_to_element(task_row).perform()
        time.sleep(0.3)
        task_row.click()
        time.sleep(0.5)
        self._shot("task_completed")

    def scroll_down(self, px: int = 400):
        self.driver.execute_script(f"window.scrollBy(0, {px});")
        time.sleep(0.3)
        self._shot("scrolled_down")

    def scroll_up(self):
        self.driver.execute_script("window.scrollTo(0, 0);")
        time.sleep(0.3)
        self._shot("scrolled_up")

    def zoom(self, level: float = 0.85):
        self.driver.execute_script(f"document.body.style.zoom='{level}'")
        time.sleep(0.3)
        self._shot("zoomed")

    def go_back(self):
        self.driver.back()
        time.sleep(1)
        self._shot("navigated_back")

    def go_forward(self):
        self.driver.forward()
        time.sleep(1)
        self._shot("navigated_forward")

    def check_language_versions(self):
        for lang, url in [
            ("english", "https://en.wikipedia.org/wiki/Main_Page"),
            ("russian", "https://ru.wikipedia.org/wiki/Заглавная_страница"),
        ]:
            print(f"\n  Loading {lang} version...")
            self.driver.get(url)
            WebDriverWait(self.driver, 15).until(
                EC.presence_of_element_located(
                    (By.CSS_SELECTOR, "#mw-content-text, #bodyContent")
                )
            )
            time.sleep(1.5)
            self._shot(f"homepage_{lang}")
            print(f"  {lang.capitalize()} - title: {self.driver.title!r}")
        self.driver.get("https://en.wikipedia.org/wiki/Special:Random")
        WebDriverWait(self.driver, 15).until(lambda d: "/wiki/" in d.current_url)
        time.sleep(1)
        self._shot("returned_to_app")


# Fixtures
@pytest.fixture(scope="session")
def driver():
    browser = os.getenv("BROWSER", "edge").strip().lower()
    if browser == "firefox":
        options = FirefoxOptions()
        drv = webdriver.Firefox(options=options)
    else:
        options = EdgeOptions()
        drv = webdriver.Edge(options=options)
    drv.maximize_window()
    yield drv
    drv.quit()


@pytest.fixture(scope="session")
def login_page(driver):
    return LoginPage(driver)


@pytest.fixture(scope="session")
def app_page(driver):
    return AppPage(driver)


# Tests
@pytest.mark.auth
@pytest.mark.smoke
def test_01_open_login_page(login_page):
    login_page.open()


@pytest.mark.auth
@pytest.mark.smoke
def test_02_login(login_page):
    login_page.login(EMAIL, PASSWORD)


@pytest.mark.auth
@pytest.mark.smoke
def test_03_app_loads(login_page, app_page):
    app_page._step = login_page._step
    app_page.wait_for_load()


@pytest.mark.auth
def test_04_save_cookies(app_page):
    app_page.save_cookies()
    assert COOKIES_FILE.exists()
    assert COOKIES_FILE.stat().st_size > 0


@pytest.mark.navigation
@pytest.mark.smoke
def test_05_go_to_inbox(app_page):
    app_page.go_to_inbox()
    assert "Main_Page" in app_page.driver.current_url


@pytest.mark.tasks
@pytest.mark.smoke
def test_06_add_task(app_page):
    app_page.add_task(f"E2E Test Article {int(time.time())}")


@pytest.mark.browser
def test_07_scroll_down(app_page):
    app_page.scroll_down(400)


@pytest.mark.navigation
def test_08_go_to_today(app_page):
    app_page.go_to_today()
    assert "/wiki/" in app_page.driver.current_url


@pytest.mark.tasks
@pytest.mark.flaky
@pytest.mark.xfail(
    reason="Article body link selectors may vary by page.",
    strict=False,
)
def test_09_complete_first_task(app_page):
    app_page.complete_first_task()


@pytest.mark.browser
def test_10_scroll_up(app_page):
    app_page.scroll_up()


@pytest.mark.browser
@pytest.mark.flaky
@pytest.mark.xfail(
    reason="Back/forward history can be non-deterministic.",
    strict=False,
)
def test_11_browser_operations(app_page):
    app_page.zoom(0.85)
    app_page.go_back()
    app_page.go_forward()


@pytest.mark.i18n
def test_12_language_versions(app_page):
    app_page.check_language_versions()
