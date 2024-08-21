async function getIp(): Promise<any> {
    return fetch('https://ipinfo.io/ip', { method: "GET" })
        .then(response => response.text())
        .then(ip => {
            process.env.ip = ip;
            return ip;
        });
}

async function getZones(): Promise<any> {
    const myHeaders = new Headers();
    myHeaders.append("Content-Type", "application/json");
    myHeaders.append("Authorization", `Bearer ${process.env.cloudflareBearer!}`);

    return fetch("https://api.cloudflare.com/client/v4/zones", { method: "GET", headers: myHeaders, })
        .then(response => response.json())
        .then((response: {
            result: {
                name: string;
                id: string
            }[]
        }) => response?.result?.find(v => v.name == process.env.zoneName)?.id!)
        .then(zoneId => {
            process.env.zoneId = zoneId;
            return zoneId;
        });
}

async function getDnsRecords(zoneId: string): Promise<any> {
    const myHeaders = new Headers();
    myHeaders.append("Content-Type", "application/json");
    myHeaders.append("Authorization", `Bearer ${process.env.cloudflareBearer!}`);

    return fetch(`https://api.cloudflare.com/client/v4/zones/${zoneId}/dns_records`, { method: "GET", headers: myHeaders, })
        .then(response => response.json())
        .then(async (response: {
            result: {
                zone_id: string;
                id: string;
                name: string;
                type: string;
            }[]
        }) => {
            return Promise.all(
                response
                    .result
                    .filter(r => r.type == 'A')
                    .map(async response => {
                        const request = {
                            "type": response.type,
                            "name": response.name,
                            "id": response.id,
                            "zone_id": response.zone_id,
                            "content": process.env.ip,
                            "ttl": 120,
                            "proxied": true
                        };

                        await updateDns(zoneId, request);
                    })
            );
        });
}

async function updateDns(zoneId: string, body: any): Promise<any> {
    const myHeaders = new Headers();
    myHeaders.append("Content-Type", "application/json");
    myHeaders.append("X-Auth-Key", `${process.env.XAuthKey!}`);
    myHeaders.append("X-Auth-Email", `${process.env.XAuthEmail!}`);

    return await fetch(`https://api.cloudflare.com/client/v4/zones/${zoneId}/dns_records/${body.id}`, { method: "PUT", headers: myHeaders, body: JSON.stringify(body) })
        .then(response => response.json())
        .then((response: {success: boolean}) => console.log(`${body.name} → ${response.success}`));
}

async function main() {
    await getIp();
    const zoneid = await getZones();
    await getDnsRecords(zoneid);
}

main();