from datetime import date, timedelta


def test_create_and_get(client, pump):
    resp = client.get(f"/equipment/{pump['id']}")
    assert resp.status_code == 200
    assert resp.json()["name"] == "Pump A"
    assert resp.json()["status"] == "operational"


def test_list_and_filter(client, pump):
    client.post(
        "/equipment",
        json={"name": "Crane", "type": "crane", "location": "Yard", "status": "maintenance"},
    )
    assert len(client.get("/equipment").json()) == 2
    filtered = client.get("/equipment", params={"status_filter": "maintenance"}).json()
    assert [e["name"] for e in filtered] == ["Crane"]


def test_update(client, pump):
    resp = client.patch(f"/equipment/{pump['id']}", json={"status": "out_of_service"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "out_of_service"
    assert resp.json()["name"] == "Pump A"


def test_delete(client, pump):
    assert client.delete(f"/equipment/{pump['id']}").status_code == 204
    assert client.get(f"/equipment/{pump['id']}").status_code == 404


def test_validation(client):
    resp = client.post("/equipment", json={"name": "", "type": "x", "location": "y"})
    assert resp.status_code == 422


def test_not_found(client):
    assert client.get("/equipment/999").status_code == 404
    assert client.get("/equipment/999/overdue").status_code == 404


def test_maintenance_records(client, pump):
    url = f"/equipment/{pump['id']}/maintenance"
    resp = client.post(url, json={"performed_at": "2026-01-10", "technician": "Sam"})
    assert resp.status_code == 201
    assert resp.json()["equipment_id"] == pump["id"]
    assert len(client.get(url).json()) == 1


def test_overdue(client, pump):
    url = f"/equipment/{pump['id']}"
    assert client.get(f"{url}/overdue").json()["overdue"] is False

    past = date.today() - timedelta(days=5)
    client.post(
        f"{url}/maintenance",
        json={"performed_at": "2026-01-01", "technician": "Sam", "next_due": past.isoformat()},
    )
    body = client.get(f"{url}/overdue").json()
    assert body["overdue"] is True
    assert body["days_overdue"] == 5

    future = date.today() + timedelta(days=30)
    client.post(
        f"{url}/maintenance",
        json={
            "performed_at": date.today().isoformat(),
            "technician": "Ana",
            "next_due": future.isoformat(),
        },
    )
    assert client.get(f"{url}/overdue").json()["overdue"] is False
