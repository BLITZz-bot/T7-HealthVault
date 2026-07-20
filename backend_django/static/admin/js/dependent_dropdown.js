document.addEventListener('DOMContentLoaded', function () {
    const stateSelect = document.getElementById('id_state');
    const areaSelect = document.getElementById('id_assigned_area');

    if (stateSelect && areaSelect) {
        stateSelect.addEventListener('change', function () {
            const stateId = this.value;
            areaSelect.innerHTML = '<option value="">---------</option>';

            if (stateId) {
                fetch(`/api/ajax/load-areas/?state_id=${stateId}`)
                    .then(response => response.json())
                    .then(data => {
                        data.forEach(area => {
                            const option = new Option(area.name, area.id);
                            areaSelect.add(option);
                        });
                    })
                    .catch(error => console.error('Error loading areas:', error));
            }
        });
    }
});
